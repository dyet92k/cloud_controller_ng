require 'kubernetes/kube_client_builder'

module Kubernetes
  class RouteResourceManager
    UPDATE_DESTINATION_CONFLICT_RETRIES = 3

    def initialize(kube_client)
      @client = kube_client
    end

    def create_route(route)
      route_resource_hash = {
        metadata: {
          name: route.guid,
          namespace: VCAP::CloudController::Config.config.kubernetes_workloads_namespace,
          labels: {
            'app.kubernetes.io/name' => route.guid,
            'app.kubernetes.io/version' => '0.0.0',
            'app.kubernetes.io/managed-by' => 'cloudfoundry',
            'app.kubernetes.io/component' => 'cf-networking',
            'app.kubernetes.io/part-of' => 'cloudfoundry',
            'cloudfoundry.org/org_guid' => route.space.organization_guid,
            'cloudfoundry.org/space_guid' => route.space.guid,
            'cloudfoundry.org/domain_guid' => route.domain.guid,
            'cloudfoundry.org/route_guid' => route.guid
          }
        },
        spec: {
          host: route.host,
          path: route.path,
          url: "#{route.fqdn}#{route.path}",
          domain: {
            name: route.domain.name,
            internal: route.internal?
          },
          destinations: []
        }
      }

      @client.create_route(Kubeclient::Resource.new(route_resource_hash))
    rescue => e
      logger.info("Failed to Create Route CRD: #{e}")
      raise
    end

    def update_destinations(route)
      remaining_retries = UPDATE_DESTINATION_CONFLICT_RETRIES
      begin
        route_resource = @client.get_route(route.guid, 'cf-workloads')
        route_resource.spec.destinations = get_destinations(route)
        @client.update_route(route_resource)
      rescue ApiClient::ConflictError
        remaining_retries -= 1
        retry if remaining_retries.positive?
        logger.info("Failed to Update Route CRD after #{UPDATE_DESTINATION_CONFLICT_RETRIES}: #{e}")
        raise
      rescue => e
        logger.info("Failed to Update Route CRD: #{e}")
        raise
      end
    end

    def delete_route(route)
      @client.delete_route(route.guid, VCAP::CloudController::Config.config.kubernetes_workloads_namespace)
    rescue => e
      logger.info("Failed to Delete Route CRD: #{e}")
      raise
    end

    private

    def logger
      Steno.logger('kubernetes.route_resource_manager')
    end

    def get_destinations(route)
      route.route_mappings.map do |route_mapping|
        destination = {
          guid: route_mapping.guid,
          port: route_mapping.presented_port,
          app: {
            guid: route_mapping.app_guid,
            process: {
              type: route_mapping.process_type,
            },
          },
          selector: {
            matchLabels: {
              'cloudfoundry.org/app_guid' => route_mapping.app_guid,
              'cloudfoundry.org/process_type' => route_mapping.process_type,
            },
          },
        }

        if route_mapping.weight.present?
          destination[:weight] = route_mapping.weight
        end

        destination
      end
    end
  end
end

module VCAP::CloudController
  class Event < Sequel::Model
    class EventValidationError < StandardError; end
    LESS_THAN_COMPARATOR = 'lt'.to_sym
    LESS_THAN_OR_EQUAL_COMPARATOR = 'lte'.to_sym
    GREATER_THAN_COMPARATOR = 'gt'.to_sym
    GREATER_THAN_OR_EQUAL_COMPARATOR = 'gte'.to_sym

    plugin :serialization

    many_to_one :space, primary_key: :guid, key: :space_guid, without_guid_generation: true

    def validate
      validates_presence :type
      validates_presence :timestamp
      validates_presence :actor
      validates_presence :actor_type
      validates_presence :actee
      validates_presence :actee_type
      validates_not_null :actee_name
    end

    serialize_attributes :json, :metadata

    export_attributes :type, :actor, :actor_type, :actor_name, :actor_username, :actee,
      :actee_type, :actee_name, :timestamp, :metadata, :space_guid,
      :organization_guid

    def data
      metadata
    end

    def target
      actee
    end

    def target_name
      actee_name
    end

    def target_type
      actee_type
    end

    def metadata
      super || {}
    end

    def before_save
      denormalize_space_and_org_guids
      super
    end

    def denormalize_space_and_org_guids
      # If we have both guids, return.
      # If we have a space, get the guids off of it.
      # If we have only an org, get the org guid from it.
      # Raise.
      if (space_guid && organization_guid) || organization_guid
        nil
      elsif space
        self.space_guid = space.guid
        self.organization_guid = space.organization.guid
      else
        raise EventValidationError.new('A Space or an organization_guid must be supplied when creating an Event.')
      end
    end

    def self.user_visibility_filter(user)
      # use select_map so the query is run now instead of being added as a where filter later. When this instead
      # generates a subselect in the filter query directly, performance degrades significantly in MySQL.
      Sequel.or([
        [:space_guid, Space.dataset.join_table(:inner, :spaces_developers, space_id: :id, user_id: user.id).select(:guid).
          union(
            Space.dataset.join_table(:inner, :spaces_auditors, space_id: :id, user_id: user.id).select(:guid)
          ).select_map(:guid)],
        [:organization_guid, Organization.dataset.where(auditors: user).select_map(:guid)]
      ])
    end
  end
end

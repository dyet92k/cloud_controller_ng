require 'spec_helper'
require 'messages/events_list_message'

module VCAP::CloudController
  RSpec.describe EventsListMessage do
    describe '.from_params' do
      let(:params) do
        {}
      end

      it 'returns the correct EventsListMessage' do
        message = EventsListMessage.from_params(params)

        expect(message).to be_a(EventsListMessage)
      end
    end

    describe 'fields' do
      it 'accepts an empty set' do
        message = EventsListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'accepts a set of fields' do
        message = EventsListMessage.from_params({
          types: ['audit.app.create'],
          target_guids: ['guid1', 'guid2'],
          space_guids: ['guid3', 'guid4'],
          organization_guids: ['guid5', 'guid6'],
          created_ats: { lt: Time.now.utc.iso8601 },
        })
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = EventsListMessage.from_params({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end

      context 'validations' do
        it 'validates the types filter' do
          message = EventsListMessage.from_params({ types: 123 })
          expect(message).not_to be_valid
          expect(message.errors[:types]).to include('must be an array')
        end

        it 'validates the target_guids filter' do
          message = EventsListMessage.from_params({ target_guids: 123 })
          expect(message).not_to be_valid
          expect(message.errors[:target_guids]).to include('must be an array')
        end

        it 'validates the space_guids filter' do
          message = EventsListMessage.from_params({ space_guids: 123 })
          expect(message).not_to be_valid
          expect(message.errors[:space_guids]).to include('must be an array')
        end

        it 'validates the organization_guids filter' do
          message = EventsListMessage.from_params({ organization_guids: 123 })
          expect(message).not_to be_valid
          expect(message.errors[:organization_guids]).to include('must be an array')
        end

        context 'validates the created_ats filter' do
          it 'requires a hash or an array of timestamps' do
            message = EventsListMessage.from_params({ created_ats: 47 })
            expect(message).not_to be_valid
            expect(message.errors[:created_ats]).to include('relational operator and timestamp must be specified')
          end

          it 'requires a valid relational operator' do
            message = EventsListMessage.from_params({ created_ats: { garbage: Time.now.utc.iso8601 } })
            expect(message).not_to be_valid
            expect(message.errors[:created_ats]).to include("Invalid relational operator: 'garbage'")
          end

          context 'requires a valid timestamp' do
            it "won't accept a malformed timestamp" do
              message = EventsListMessage.from_params({ 'created_ats' => "#{Time.now.utc.iso8601},bogus" })
              expect(message).not_to be_valid
              expect(message.errors[:created_ats]).to include("has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'")
            end

            it "won't accept garbage" do
              message = EventsListMessage.from_params({ created_ats: { gt: 123 } })
              expect(message).not_to be_valid
              expect(message.errors[:created_ats]).to include("has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'")
            end

            it "won't accept fractional seconds even though it's ISO 8601-compliant" do
              message = EventsListMessage.from_params({ created_ats: { gt: '2020-06-30T12:34:56.78Z' } })
              expect(message).not_to be_valid
              expect(message.errors[:created_ats]).to include("has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'")
            end

            it "won't accept local time zones even though it's ISO 8601-compliant" do
              message = EventsListMessage.from_params({ created_ats: { gt: '2020-06-30T12:34:56.78-0700' } })
              expect(message).not_to be_valid
              expect(message.errors[:created_ats]).to include("has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'")
            end
          end

          it 'allows comma-separated timestamps' do
            message = EventsListMessage.from_params({ 'created_ats' => "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}" })
            expect(message).to be_valid
          end

          it 'allows the lt operator' do
            message = EventsListMessage.from_params({ created_ats: { lt: Time.now.utc.iso8601 } })
            expect(message).to be_valid
          end

          it 'allows the lte operator' do
            message = EventsListMessage.from_params({ created_ats: { lte: Time.now.utc.iso8601 } })
            expect(message).to be_valid
          end

          it 'allows the gt operator' do
            message = EventsListMessage.from_params({ created_ats: { gt: Time.now.utc.iso8601 } })
            expect(message).to be_valid
          end

          it 'allows the gte operator' do
            message = EventsListMessage.from_params({ created_ats: { gte: Time.now.utc.iso8601 } })
            expect(message).to be_valid
          end

          it 'does not allow multiple timestamps with an operator' do
            message = EventsListMessage.from_params({ created_ats: { gte: "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}" } })
            expect(message).not_to be_valid
            expect(message.errors[:created_ats]).to include('only accepts one value when using a relational operator')
          end

          context 'when the operator is an equals operator' do
            it 'allows the equals operator' do
              message = EventsListMessage.from_params({ 'created_ats' => Time.now.utc.iso8601 })
              expect(message).to be_valid
            end
          end
        end
      end
    end
  end
end

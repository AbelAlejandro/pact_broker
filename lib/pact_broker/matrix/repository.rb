require 'pact_broker/repositories/helpers'

module PactBroker
  module Matrix
    class Repository
      include PactBroker::Repositories::Helpers
      include PactBroker::Repositories

      def find criteria
        version_ids = criteria.reject{ |key, value| !value }.collect do | key, value |
          version_repository.find_by_pacticipant_name_and_number(key, value).id
        end

        pacticipant_names = criteria.reject{|key, value| value }.keys

        # If there is a nil provider_version_number it is because there is no verification
        # but the row has been included because it is a left outer join.
        # All the unverified pacts will be grouped together in the group_by because of this,
        # so we include all of that group.
        find_for_version_ids(version_ids, pacticipant_names)
          .group_by{|line| [line[:consumer_version_number], line[:provider_version_number]]}
          .values
          .collect{ | lines | lines.first[:provider_version_number].nil? ? lines : lines.last }
          .flatten
      end

      def find_for_consumer_and_provider pacticipant_1_name, pacticipant_2_name
        find_for_version_ids([], [pacticipant_1_name, pacticipant_2_name])
          .sort{|l1, l2| l2[:consumer_version_order] <=> l1[:consumer_version_order]}
      end

      ##
      # criteria Hash of pacticipant_name => version
      # Ihe value is nil, it means all versions for that pacticipant are to be included
      # Returns a list of matrix lines indicating the compatible versions
      #
      def find_compatible_pacticipant_versions criteria
        find(criteria).select{ |line | line[:success] }
      end

      def find_for_version_ids version_ids, pacticipant_names = []
        PactBroker::Pacts::LatestPactPublicationsByConsumerVersion
          .select_append(:consumer_version_number, :provider_name, :consumer_name, :provider_version_id, :provider_version_number, :success)
          .select_append(Sequel[:latest_pact_publications_by_consumer_versions][:created_at].as(:pact_created_at))
          .select_append(Sequel[:all_verifications][:number])
          .select_append(Sequel[:all_verifications][:id].as(:verification_id))
          .select_append(Sequel[:execution_date].as(:verification_executed_at))
          .left_outer_join(:all_verifications, pact_version_id: :pact_version_id)
          .where(provider_version_id: version_ids)
            .or(provider_version_id: nil)
            .or(provider_name: pacticipant_names)
          .where(consumer_version_id: version_ids)
            .or(consumer_name: pacticipant_names)
          .order(:execution_date, :verification_id)
          .collect(&:values)
      end
    end
  end
end

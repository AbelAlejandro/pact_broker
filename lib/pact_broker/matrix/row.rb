require 'pact_broker/repositories/helpers'
require 'pact_broker/webhooks/latest_triggered_webhook'

module PactBroker
  module Matrix
    class Row < Sequel::Model(:matrix)


      associate(:one_to_many, :latest_triggered_webhooks, :class => "PactBroker::Webhooks::LatestTriggeredWebhook", primary_key: :pact_publication_id, key: :pact_publication_id)

      # already have this
      # associate(:many_to_one, :latest_verification, :class => "PactBroker::Verifications::Repository::LatestVerificationsByConsumerVersion", primary_key: :pact_version_id, key: :pact_version_id)
      # TODO modify this to work with single pacticipant webhooks
      associate(:one_to_many, :webhooks, :class => "PactBroker::Webhooks::Webhook", primary_key: [:consumer_id, :provider_id], key: [:consumer_id, :provider_id])
      associate(:one_to_many, :consumer_version_tags, :class => "PactBroker::Domain::Tag", primary_key: :consumer_version_id, key: :version_id)

      dataset_module do
        include PactBroker::Repositories::Helpers

        def matching_selectors selectors
          if selectors.size == 1
            where_consumer_or_provider_is(selectors.first)
          else
            where_consumer_and_provider_in(selectors)
          end
        end

        def where_consumer_and_provider_in selectors
          where{
            Sequel.&(
              Sequel.|(
                *selectors.collect{ |s| s[:pacticipant_version_number] ? Sequel.&(consumer_name: s[:pacticipant_name], consumer_version_number: s[:pacticipant_version_number]) :  Sequel.&(consumer_name: s[:pacticipant_name]) }
              ),
              Sequel.|(
                *(selectors.collect{ |s| s[:pacticipant_version_number] ? Sequel.&(provider_name: s[:pacticipant_name], provider_version_number: s[:pacticipant_version_number]) :  Sequel.&(provider_name: s[:pacticipant_name]) } +
                  selectors.collect{ |s| Sequel.&(provider_name: s[:pacticipant_name], provider_version_number: nil) })
              )
            )
          }
        end

        def where_consumer_or_provider_is s
          where{
            Sequel.|(
              s[:pacticipant_version_number] ? Sequel.&(consumer_name: s[:pacticipant_name], consumer_version_number: s[:pacticipant_version_number]) :  Sequel.&(consumer_name: s[:pacticipant_name]),
              s[:pacticipant_version_number] ? Sequel.&(provider_name: s[:pacticipant_name], provider_version_number: s[:pacticipant_version_number]) :  Sequel.&(provider_name: s[:pacticipant_name])
            )
          }
        end

        def order_by_names_ascending_most_recent_first
          order(
            Sequel.asc(:consumer_name),
            Sequel.desc(:consumer_version_order),
            Sequel.desc(:pact_revision_number),
            Sequel.asc(:provider_name),
            Sequel.desc(:provider_version_order),
            Sequel.desc(:verification_id))
        end
      end

      def latest_triggered_webhooks
        @latest_triggered_webhooks ||= []
      end

      def summary
        "#{consumer_name}#{consumer_version_number} #{provider_name}#{provider_version_number || '?'} (r#{pact_revision_number}n#{verification_number || '?'})"
      end

      def consumer
        @consumer ||= OpenStruct.new(name: consumer_name, id: consumer_id)
      end

      def provider
        @provider ||= OpenStruct.new(name: provider_name, id: provider_id)
      end

      def consumer_version
        @consumer_version ||= OpenStruct.new(number: consumer_version_number, id: consumer_version_id)
      end

      def provider_version
        if provider_version_number
          @provider_version ||= OpenStruct.new(number: provider_version_number, id: provider_version_id)
        end
      end

      def pact
        @pact ||= OpenStruct.new(consumer: consumer,
          provider: provider,
          consumer_version: consumer_version,
          consumer_version_number: consumer_version_number,
          created_at: pact_created_at,
          revision_number: pact_revision_number,
          pact_version_sha: pact_version_sha
        )
      end

      def latest_verification
        if verification_executed_at
          @latest_verification ||= OpenStruct.new(
            id: verification_id,
            success: success,
            number: verification_number,
            execution_date: verification_executed_at,
            provider_version_number: provider_version_number,
            build_url: verification_build_url,
            provider_version: provider_version
          )
        end
      end

      # Add logic for ignoring case
      def <=> other
        comparisons = [
          compare_name_asc(consumer_name, other.consumer_name),
          compare_number_desc(consumer_version_order, other.consumer_version_order),
          compare_number_desc(pact_revision_number, other.pact_revision_number),
          compare_name_asc(provider_name, other.provider_name),
          compare_number_desc(provider_version_order, other.provider_version_order),
          compare_number_desc(verification_id, other.verification_id)
        ]

        comparisons.find{|c| c != 0 } || 0

      end

      def compare_name_asc name1, name2
        name1 <=> name2
      end

      def compare_number_desc number1, number2
        if number1 && number2
          number2 <=> number1
        elsif number1
          1
        else
          -1
        end
      end
    end
  end
end

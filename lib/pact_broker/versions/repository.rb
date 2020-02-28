require 'sequel'
require 'pact_broker/logging'
require 'pact_broker/domain/version'
require 'pact_broker/tags/repository'

module PactBroker
  module Versions
    class Repository

      include PactBroker::Logging
      include PactBroker::Repositories::Helpers

      def find_by_pacticipant_id_and_number pacticipant_id, number
        PactBroker::Domain::Version.where(number: number, pacticipant_id: pacticipant_id).single_record
      end

      def find_by_pacticipant_name_and_latest_tag pacticipant_name, tag
        PactBroker::Domain::Version
          .select_all_qualified
          .join(:tags, {version_id: :id}, {implicit_qualifier: :versions})
          .where(name_like(Sequel[:tags][:name], tag))
          .where_pacticipant_name(pacticipant_name)
          .reverse_order(:order)
          .first
      end

      def find_by_pacticipant_name_and_tag pacticipant_name, tag
        PactBroker::Domain::Version
          .select_all_qualified
          .where_pacticipant_name(pacticipant_name)
          .join(:tags, {version_id: :id}, {implicit_qualifier: :versions})
          .where(name_like(Sequel[:tags][:name], tag))
          .all
      end

      def find_latest_by_pacticpant_name pacticipant_name
        PactBroker::Domain::Version
          .select_all_qualified
          .where_pacticipant_name(pacticipant_name)
          .reverse_order(:order)
          .first
      end

      def find_by_pacticipant_name_and_number pacticipant_name, number
        PactBroker::Domain::Version
          .select(Sequel[:versions][:id], Sequel[:versions][:number], Sequel[:versions][:pacticipant_id], Sequel[:versions][:order], Sequel[:versions][:created_at], Sequel[:versions][:updated_at])
          .where(name_like(:number, number))
          .where_pacticipant_name(pacticipant_name)
          .single_record
      end

      # There may be a race condition if two simultaneous requests come in to create the same version
      def create args
        logger.info "Upserting version #{args[:number]} for pacticipant_id=#{args[:pacticipant_id]}"
        version_params = {
          number: args[:number],
          pacticipant_id: args[:pacticipant_id],
          created_at: Sequel.datetime_class.now,
          updated_at: Sequel.datetime_class.now
        }
        id = PactBroker::Domain::Version.dataset.insert_ignore.insert(version_params)
        version = PactBroker::Domain::Version.find(number: args[:number], pacticipant_id: args[:pacticipant_id])
        PactBroker::Domain::OrderVersions.(version)
        version.refresh # reload with the populated order
      end

      def find_by_pacticipant_id_and_number_or_create pacticipant_id, number
        if version = find_by_pacticipant_id_and_number(pacticipant_id, number)
          version
        else
          create(pacticipant_id: pacticipant_id, number: number)
        end
      end

      def delete_by_id version_ids
        Domain::Version.where(id: version_ids).delete
      end

      def delete_orphan_versions consumer, provider
        version_ids_with_pact_publications = PactBroker::Pacts::PactPublication.where(consumer_id: [consumer.id, provider.id]).select(:consumer_version_id).collect{|r| r[:consumer_version_id]}
        version_ids_with_verifications = PactBroker::Domain::Verification.where(provider_id: [provider.id, consumer.id]).select(:provider_version_id).collect{|r| r[:provider_version_id]}
        # Hope we don't hit max parameter constraints here...
        version_ids_to_keep = (version_ids_with_pact_publications + version_ids_with_verifications).uniq

        PactBroker::Domain::Version
          .where(pacticipant_id: [consumer.id, provider.id])
          .exclude(id: (version_ids_with_pact_publications + version_ids_with_verifications).uniq)
          .delete
      end

      def find_versions_for_selector(selector)
        if selector.tag && selector.latest
          version = find_by_pacticipant_name_and_latest_tag(selector.pacticipant_name, selector.tag)
          [version]
        elsif selector.latest
          version = find_latest_by_pacticpant_name(selector.pacticipant_name)
          [version]
        elsif selector.tag
          versions = find_by_pacticipant_name_and_tag(selector.pacticipant_name, selector.tag)
          versions.any? ? versions : [nil]
        elsif selector.pacticipant_version_number
          version = find_by_pacticipant_name_and_number(selector.pacticipant_name, selector.pacticipant_version_number)
          [version]
        else
          nil
        end
      end
    end
  end
end

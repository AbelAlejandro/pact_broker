require 'sequel'
require 'pact_broker/project_root'

module PactBroker
  module DB
    class Clean
      def self.call database_connection, options = {}
        new(database_connection, options).call
      end

      def initialize database_connection, options = {}
        @db = database_connection
        @options = options
      end

      def keep
        options[:keep] || [PactBroker::Matrix::UnresolvedSelector.new(tag: true, latest: true)]
      end

      def resolve_ids(query)
        query
        # result = query.collect { |h| h[:id] }
        # def result.union(other)
        #   self + other
        # end
        # result
      end

      def pact_publication_ids_to_keep
        @pact_publication_ids_to_keep ||= pact_publication_ids_to_keep_for_version_ids_to_keep.union(pact_publications_to_keep_for_verification_ids_to_keep)
      end

      def pact_publication_ids_to_keep_for_version_ids_to_keep
        @pact_publication_ids_to_keep_for_version_ids_to_keep ||= resolve_ids(db[:pact_publications].select(:id).where(consumer_version_id: version_ids_to_keep))
      end

      def pact_publications_to_keep_for_verification_ids_to_keep
        @pact_publications_to_keep_for_verification_ids_to_keep ||= resolve_ids(db[:pact_publications].select(:id).where(pact_version_id: db[:verifications].select(:pact_version_id).where(id: verification_ids_to_keep_for_version_ids_to_keep)))
      end

      def pact_publication_ids_to_delete
        @pact_publication_ids_to_delete ||= resolve_ids(db[:pact_publications].select(:id).where(id: pact_publication_ids_to_keep).invert)

        # else
          # keep = db[:latest_tagged_pact_publications].select(:id).union(db[:latest_pact_publications].select(:id))
          # db[:pact_publications].select(:id).where(id: keep).invert
        # end
      end

      # because they belong to the versions to keep
      def verification_ids_to_keep_for_version_ids_to_keep
        @verification_ids_to_keep_for_version_ids_to_keep ||= resolve_ids(db[:verifications].select(:id).where(provider_version_id: version_ids_to_keep))
      end

      def verification_ids_to_keep_for_pact_publication_ids_to_keep
        @verification_ids_to_keep_for_pact_publication_ids_to_keep ||= resolve_ids(db[:verifications].select(:id).where(pact_version_id: db[:pact_publications].select(:pact_version_id).where(id: pact_publication_ids_to_keep_for_version_ids_to_keep)))
      end

      def verification_ids_to_keep
        @verification_ids_to_keep ||= verification_ids_to_keep_for_version_ids_to_keep.union(verification_ids_to_keep_for_pact_publication_ids_to_keep)
      end

      def verification_ids_to_delete
        @verification_ids_to_delete ||= db[:verifications].select(:id).where(id: verification_ids_to_keep).invert
      end

      def version_ids_to_keep
        @version_ids_to_keep ||= keep.collect do | selector |
          PactBroker::Domain::Version.select(:id).for_selector(selector)
        end.reduce(&:union)
      end

      def call
        deleted_counts = {}
        kept_counts = {}

        pact_publications_to_keep = db[:pact_publications].where(id: pact_publication_ids_to_delete).invert

        deleted_counts[:pact_publications] = pact_publication_ids_to_delete.count
        kept_counts[:pact_publications] = pact_publications_to_keep.count

        # Work out how to keep the head verifications for the provider tags.

        deleted_counts[:verification_results] = verification_ids_to_delete.count
        kept_counts[:verification_results] = verification_ids_to_keep.count

        delete_webhook_data(verification_triggered_webhook_ids_to_delete)
        delete_verifications

        delete_webhook_data(pact_publication_triggered_webhook_ids_to_delete)
        delete_pact_publications

        delete_orphan_pact_versions
        overwritten_delete_counts = delete_overwritten_verifications
        deleted_counts[:verification_results] = deleted_counts[:verification_results] + overwritten_delete_counts[:verification_results]
        kept_counts[:verification_results] = kept_counts[:verification_results] - overwritten_delete_counts[:verification_results]

        delete_orphan_tags
        delete_orphan_versions

        { kept: kept_counts, deleted: deleted_counts }
      end

      private

      attr_reader :db, :options

      def verification_triggered_webhook_ids_to_delete
        db[:triggered_webhooks].select(:id).where(verification_id: verification_ids_to_delete)
      end

      def pact_publication_triggered_webhook_ids_to_delete
        db[:triggered_webhooks].select(:id).where(pact_publication_id: pact_publication_ids_to_delete)
      end

      def referenced_version_ids
        db[:pact_publications].select(:consumer_version_id).union(db[:verifications].select(:provider_version_id))
      end

      def verification_ids_for_pact_publication_ids_to_delete
        @verification_ids_for_pact_publication_ids_to_delete ||=
          db[:verifications].select(:id).where(pact_version_id: db[:pact_publications].select(:pact_version_id).where(id: pact_publication_ids_to_delete))
      end

      def delete_webhook_data(triggered_webhook_ids)
        db[:webhook_executions].where(triggered_webhook_id: triggered_webhook_ids).delete
        db[:triggered_webhooks].where(id: triggered_webhook_ids).delete
      end

      def delete_pact_publications
        db[:pact_publications].where(id: pact_publication_ids_to_delete).delete
      end

      def delete_verifications
        db[:verifications].where(id: verification_ids_to_delete).delete
      end

      def delete_orphan_pact_versions
        referenced_pact_version_ids = db[:pact_publications].select(:pact_version_id).union(db[:verifications].select(:pact_version_id))
        db[:pact_versions].where(id: referenced_pact_version_ids).invert.delete
      end

      def delete_orphan_tags
        db[:tags].where(version_id: referenced_version_ids).invert.delete
      end

      def delete_orphan_versions
        db[:versions].where(id: referenced_version_ids).invert.delete
      end

      def delete_overwritten_verifications
        verification_ids = db[:verifications].select(:id).where(id: db[:latest_verification_id_for_pact_version_and_provider_version].select(:verification_id)).invert
        deleted_counts = { verification_results: verification_ids.count }
        delete_webhook_data(db[:triggered_webhooks].where(verification_id: verification_ids).select(:id))
        verification_ids.delete
        deleted_counts
      end
    end
  end
end

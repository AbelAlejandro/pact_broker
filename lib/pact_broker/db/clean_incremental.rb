require 'pact_broker/logging'
require 'pact_broker/matrix/unresolved_selector'
require 'pact_broker/date_helper'


module PactBroker
  module DB
    class CleanIncremental
      DEFAULT_KEEP_SELECTORS = [
        PactBroker::Matrix::UnresolvedSelector.new(tag: true, latest: true),
        PactBroker::Matrix::UnresolvedSelector.new(latest: true),
        PactBroker::Matrix::UnresolvedSelector.new(max_age: 90)
      ]
      TABLES = [:versions, :pact_publications, :pact_versions, :verifications, :triggered_webhooks, :webhook_executions]

      def self.call database_connection, options = {}
        new(database_connection, options).call
      end

      def initialize database_connection, options = {}
        @db = database_connection
        @options = options
      end

      def logger
        options[:logger] || PactBroker.logger
      end

      def keep
        options[:keep] || DEFAULT_KEEP_SELECTORS
      end

      def limit
        options[:limit] || 1000
      end

      def resolve_ids(query, column_name = :id)
        query.collect { |h| h[column_name] }
      end

      def version_ids_to_delete
        db[:versions].where(id: version_ids_to_keep).invert.limit(limit).order(Sequel.asc(:id))
      end

      def version_ids_to_keep
        @version_ids_to_keep ||= keep.collect do | selector |
          PactBroker::Domain::Version.select(:id).for_selector(selector)
        end.reduce(&:union)
      end

      def call
        require 'pact_broker/db/models'

        if dry_run?
          PactBroker::Domain::Version
            .where(id: version_ids_to_delete.select(:id))
            .all
            .group_by{ | v | v.pacticipant_id }
            .each_with_object({}) do | (pacticipant_id, versions), thing |
              thing[versions.first.pacticipant.name] = {
                count: versions.count,
                from_version: {
                  number: versions.first.number,
                  created: DateHelper.distance_of_time_in_words(versions.first.created_at, DateTime.now) + " ago",
                  tags: versions.first.tags.collect(&:name)
                },
                to_version: {
                  number: versions.last.number,
                  created: DateHelper.distance_of_time_in_words(versions.last.created_at, DateTime.now) + " ago",
                  tags: versions.last.tags.collect(&:name)
                }
              }
            end
        else
          before_counts = current_counts
          result = PactBroker::Domain::Version.where(id: resolve_ids(version_ids_to_delete)).delete
          delete_orphan_pact_versions
          after_counts = current_counts

          TABLES.each_with_object({}) do | table_name, comparison_counts |
            comparison_counts[table_name.to_s] = { "deleted" => before_counts[table_name] - after_counts[table_name], "kept" => after_counts[table_name] }
          end
        end
      end

      private

      attr_reader :db, :options

      def current_counts
        TABLES.each_with_object({}) do | table_name, counts |
          counts[table_name] = db[table_name].count
        end
      end

      def dry_run?
        options[:dry_run]
      end

      def delete_orphan_pact_versions
        referenced_pact_version_ids = db[:pact_publications].select(:pact_version_id).union(db[:verifications].select(:pact_version_id))
        db[:pact_versions].where(id: referenced_pact_version_ids).invert.delete
      end
    end
  end
end

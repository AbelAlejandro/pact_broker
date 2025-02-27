module PactBroker
  module Pacts
    module PactPublicationSelectorDatasetModule
      # rubocop: disable Metrics/CyclomaticComplexity
      def for_provider_and_consumer_version_selector provider, selector
        query = for_provider(provider)
        query = query.for_consumer(PactBroker::Domain::Pacticipant.find_by_name(selector.consumer)) if selector.consumer
        query = query.for_currently_deployed_versions(selector.environment_name) if selector.currently_deployed?
        query = query.for_currently_supported_versions(selector.environment_name) if selector.currently_supported?
        query = query.for_consumer_version_tag(selector.tag) if selector.all_for_tag?

        if selector.environment_name && !selector.currently_deployed? && !selector.currently_supported?
          query = query.for_environment(selector.environment_name)
        end

        # Do the "latest" logic last so that the provider/consumer criteria get included in the "latest" query before the join, rather than after
        query = query.latest_for_main_branches if selector.latest_for_main_branch?
        query = query.latest_for_consumer_branch(selector.branch) if selector.latest_for_branch?
        query = query.latest_for_consumer_tag(selector.tag) if selector.latest_for_tag?
        query = query.overall_latest if selector.overall_latest?
        query
      end
      # rubocop: enable Metrics/CyclomaticComplexity

      def latest_for_main_branches
        self_join = {
          Sequel[:pact_publications][:provider_id] => Sequel[:pp2][:provider_id],
          Sequel[:pact_publications][:consumer_id] => Sequel[:pp2][:consumer_id],
          Sequel[:cv][:branch] => Sequel[:pp2][:branch]
        }

        base_query = join_consumers(:consumers)
                      .join_consumer_versions(:cv, { Sequel[:cv][:branch] => Sequel[:consumers][:main_branch] })

        base_query = base_query.select_all_qualified if no_columns_selected?

        base_query.left_join(base_query.select(:provider_id, :consumer_id, Sequel[:cv][:branch], :consumer_version_order), self_join, { table_alias: :pp2 }) do
          Sequel[:pp2][:consumer_version_order] > Sequel[:pact_publications][:consumer_version_order]
        end
        .where(Sequel[:pp2][:consumer_version_order] => nil)
      end

      def for_currently_deployed_versions(environment_name)
        deployed_versions_join = {
          Sequel[:pact_publications][:consumer_version_id] => Sequel[:deployed_versions][:version_id]
        }
        currently_deployed_versions_join = {
          Sequel[:deployed_versions][:id] => Sequel[:currently_deployed_version_ids][:deployed_version_id]
        }
        environments_join = {
          Sequel[:deployed_versions][:environment_id] => Sequel[:environments][:id],
          Sequel[:environments][:name] => environment_name
        }.compact

        query = self
        if no_columns_selected?
          query = query.select_all_qualified.select_append(Sequel[:environments][:name].as(:environment_name), Sequel[:deployed_versions][:target].as(:target))
        end
        query
          .join(:deployed_versions, deployed_versions_join)
          .join(:currently_deployed_version_ids, currently_deployed_versions_join)
          .join(:environments, environments_join)
      end

      def for_currently_supported_versions(environment_name)
        released_versions_join = {
          Sequel[:pact_publications][:consumer_version_id] => Sequel[:released_versions][:version_id],
          Sequel[:released_versions][:support_ended_at] => nil
        }
        environments_join = {
          Sequel[:released_versions][:environment_id] => Sequel[:environments][:id],
          Sequel[:environments][:name] => environment_name
        }.compact

        query = self
        if no_columns_selected?
          query = query.select_all_qualified.select_append(Sequel[:environments][:name].as(:environment_name), Sequel.lit("NULL").as(:target))
        end
        query
          .join(:released_versions, released_versions_join)
          .join(:environments, environments_join)
      end

      def for_environment(environment_name)
        for_currently_deployed_versions(environment_name).union(for_currently_supported_versions(environment_name))
      end
    end
  end
end

require 'pact_broker/repositories/helpers'
require 'pact_broker/matrix/row'
require 'pact_broker/matrix/latest_row'

module PactBroker
  module Matrix
    class Repository
      include PactBroker::Repositories::Helpers
      include PactBroker::Repositories

      # TODO move latest verification logic in to database

      GROUP_BY_PROVIDER_VERSION_NUMBER = [:consumer_name, :consumer_version_number, :provider_name, :provider_version_number]
      GROUP_BY_PROVIDER = [:consumer_name, :consumer_version_number, :provider_name]
      GROUP_BY_PACT = [:consumer_name, :provider_name]

      # Return the latest matrix row (pact/verification) for each consumer_version_number/provider_version_number
      def find selectors, options = {}
        # The group with the nil provider_version_numbers will be the results of the left outer join
        # that don't have verifications, so we need to include them all.
        lines = find_all(resolve_selectors(selectors, options), options)
        lines = apply_scope(options, selectors, lines)

        if options.key?(:success)
          lines = lines.select{ |l| options[:success].include?(l.success) }
        end

        lines.sort.collect(&:values)
      end

      def all_versions_specified? selectors
        selectors.all?{ |s| s[:pacticipant_version_number] }
      end

      def apply_scope options, selectors, lines
        return lines unless options[:latestby] == 'cvp' || options[:latestby] == 'cp'

        group_by_columns = case options[:latestby]
        when 'cvp' then GROUP_BY_PROVIDER
        when 'cp' then GROUP_BY_PACT
        end

        lines.group_by{|line| group_by_columns.collect{|key| line.send(key) }}
          .values
          .collect{ | lines | lines.first.provider_version_number.nil? ? lines : lines.first }
          .flatten
      end

      def find_for_consumer_and_provider pacticipant_1_name, pacticipant_2_name
        selectors = [{ pacticipant_name: pacticipant_1_name }, { pacticipant_name: pacticipant_2_name }]
        options = { latestby: 'cvpv' }
        find_all(resolve_selectors(selectors, options), options).sort.collect(&:values)
      end

      def find_compatible_pacticipant_versions selectors
        find(selectors, latestby: 'cvpv').select{|line| line[:success] }
      end

      ##
      # If the version is nil, it means all versions for that pacticipant are to be included
      #
      def find_all selectors, options
        query = base_table(options).select_all
        query = where_row_matches_selectors selectors, query
        query = query.limit(options[:limit]) if options[:limit]
        query.order(
          Sequel.asc(:consumer_name),
          Sequel.desc(:consumer_version_order),
          Sequel.desc(:pact_revision_number),
          Sequel.asc(:provider_name),
          Sequel.desc(:provider_version_order),
          Sequel.desc(:verification_id)).all
      end

      def base_table(options)
        return Row unless options[:latestby]
        return LatestRow
      end

      def resolve_selectors(selectors, options)
        selectors = look_up_versions_for_tags(selectors, options)

        if options[:latest]
          apply_latest_and_tag_to_inferred_selectors(selectors, options)
        else
          selectors
        end
      end

      def look_up_versions_for_tags(selectors, options)
        selectors.collect do | selector |
          # resource validation currently stops tag being specified without latest=true
          if selector[:tag] && selector[:latest]
            version = version_repository.find_by_pacticpant_name_and_latest_tag(selector[:pacticipant_name], selector[:tag])
            raise "Could not find version with tag #{selector[:tag].inspect} for #{selector[:pacticipant_name]}" unless version
            # validation in resource should ensure we always have a version
            {
              pacticipant_name: selector[:pacticipant_name],
              pacticipant_version_number: version.number
            }
          elsif selector[:latest]
            version = version_repository.find_latest_by_pacticpant_name(selector[:pacticipant_name])
            {
              pacticipant_name: selector[:pacticipant_name],
              pacticipant_version_number: version.number
            }
          else
            selector
          end
        end
      end

      def apply_latest_and_tag_to_inferred_selectors(selectors, options)
        all_pacticipant_names = all_pacticipant_names_in_specified_matrix(selectors, options)
        specified_names = selectors.collect{ |s| s[:pacticipant_name] }
        inferred_names = all_pacticipant_names - specified_names

        inferred_selectors = inferred_names.collect do | pacticipant_name |
          {
            pacticipant_name: pacticipant_name,
            latest: options[:latest]
          }.tap { |it| it[:tag] = options[:tag] if options[:tag] }
        end

        selectors + look_up_versions_for_tags(inferred_selectors, options)
      end

      def all_pacticipant_names_in_specified_matrix(selectors, options)
        query = base_table(options).select(:consumer_name, :provider_name)
        query = where_row_matches_selectors(selectors, query)
        query
          .all
          .collect{ | row | [row.consumer_name, row.provider_name] }
          .flatten
          .uniq
      end

      def where_row_matches_selectors selectors, query
        if selectors.size == 1
          where_consumer_or_provider_is(selectors.first, query)
        else
          where_consumer_and_provider_in(selectors, query)
        end
      end

      def where_consumer_and_provider_in selectors, query
          query.where{
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

      def where_consumer_or_provider_is s, query
        query.where{
          Sequel.|(
            s[:pacticipant_version_number] ? Sequel.&(consumer_name: s[:pacticipant_name], consumer_version_number: s[:pacticipant_version_number]) :  Sequel.&(consumer_name: s[:pacticipant_name]),
            s[:pacticipant_version_number] ? Sequel.&(provider_name: s[:pacticipant_name], provider_version_number: s[:pacticipant_version_number]) :  Sequel.&(provider_name: s[:pacticipant_name])
          )
        }
      end
    end
  end
end

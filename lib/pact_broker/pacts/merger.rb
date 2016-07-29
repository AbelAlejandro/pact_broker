require 'json'

module PactBroker
  module Pacts
    module Merger

      extend self

      # Accepts two hashes representing pacts, outputs a merged hash
      # Does not make any guarantees about order of interactions
      def merge_pacts original_json, additional_json
        original, additional = [original_json, additional_json].map{|str| JSON.parse(str, PACT_PARSING_OPTIONS) }

        new_pact = original

        additional["interactions"].each do |new_interaction|
          # check to see if this interaction matches an existing interaction
          overwrite_index = original["interactions"].find_index do |original_interaction|
            matching_request?(original_interaction, new_interaction)
          end

          # overwrite existing interaction if a match is found, otherwise appends the new interaction
          if overwrite_index
            new_pact["interactions"][overwrite_index] = new_interaction
          else
            new_pact["interactions"] << new_interaction
          end
        end

        new_pact.to_json
      end

      private

      def matching_request? original_interaction, new_interaction
        same_description_and_state?(original_interaction, new_interaction) &&
          same_request_properties?(original_interaction["request"], new_interaction["request"])
      end

      def same_description_and_state? original, additional
        original["description"] == additional["description"] &&
          original["provider_state"] == additional["provider_state"]
      end

      def same_request_properties? original, additional
        method_matches = original["method"] == additional["method"]
        path_matches = original["path"] == additional["path"]

        method_matches && path_matches && original["headers"] == additional["headers"]
      end
    end
  end
end

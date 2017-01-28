require 'pact_broker/api/resources/base_resource'

module PactBroker
  module Api
    module Resources

      class Tag < BaseResource

        def content_types_provided
          [["application/hal+json", :to_json]]
        end

        def content_types_accepted
          [["application/json", :from_json]]
        end

        def allowed_methods
          ["GET","PUT","DELETE"]
        end

        def from_json
          unless tag
            @tag = tag_service.create identifier_from_path
            # Make it return a 201 by setting the Location header
            response.headers["Location"] = tag_url(base_url, tag)
          end
          response.body = to_json
        end

        def resource_exists?
          tag
        end

        def to_json
          PactBroker::Api::Decorators::TagDecorator.new(tag).to_json(base_url: base_url)
        end

        def tag
          @tag ||= tag_service.find identifier_from_path
        end

        def delete_resource
          tag_service.delete tag_name, pacticipant_name, pacticipant_version_number
          true
        end

        def tag_name
          identifier_from_path[:tag_name]
        end

        def pacticipant_name
          identifier_from_path[:pacticipant_name]
        end

        def pacticipant_version_number
          identifier_from_path[:pacticipant_version_number]
        end

      end
    end

  end
end
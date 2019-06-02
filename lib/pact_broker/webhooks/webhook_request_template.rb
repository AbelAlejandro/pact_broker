require 'pact_broker/domain/webhook_request_header'
require 'pact_broker/webhooks/render'
require 'cgi'
require 'pact_broker/domain/webhook_request'

module PactBroker
  module Webhooks
    class WebhookRequestTemplate

      include PactBroker::Logging
      include PactBroker::Messages
      HEADERS_TO_REDACT = [/authorization/i, /token/i]

      attr_accessor :method, :url, :headers, :body, :username, :password, :uuid

      # Reform gets confused by the :method method, as :method is a standard
      # Ruby method.
      alias_method :http_method, :method

      def initialize attributes = {}
        @method = attributes[:method]
        @url = attributes[:url]
        @username = attributes[:username]
        @password = attributes[:password]
        @headers = Rack::Utils::HeaderHash.new(attributes[:headers] || {})
        @body = attributes[:body]
        @uuid = attributes[:uuid]
      end

      def build(context)
        template_params = PactBroker::Webhooks::PactAndVerificationParameters.new(context[:pact], context[:verification], context[:webhook_context]).to_hash
        attributes = {
          method: http_method,
          url: build_url(template_params),
          headers: headers,
          username: username,
          password: password,
          uuid: uuid,
          body: build_body(template_params)
        }
        PactBroker::Domain::WebhookRequest.new(attributes)
      end

      def build_url(template_params)
        URI(PactBroker::Webhooks::Render.call(url, template_params){ | value | CGI::escape(value) if !value.nil? } ).to_s
      end

      def build_body(template_params)
        body_string = String === body ? body : body.to_json
        PactBroker::Webhooks::Render.call(body_string, template_params)
      end

      def description
        "#{http_method.upcase} #{URI(url.gsub(PactBroker::Webhooks::Render::TEMPLATE_PARAMETER_REGEXP, 'placeholder')).host}"
      end

      def display_password
        password.nil? ? nil : "**********"
      end

      def redacted_headers
        headers.each_with_object({}) do | (name, value), new_headers |
          redact = HEADERS_TO_REDACT.any?{ | pattern | name =~ pattern }
          new_headers[name] = redact ? "**********" : value
        end
      end

      def headers= headers
        @headers = Rack::Utils::HeaderHash.new(headers)
      end

      private

      def to_s
        "#{method.upcase} #{url}, username=#{username}, password=#{display_password}, headers=#{redacted_headers}, body=#{body}"
      end
    end
  end
end

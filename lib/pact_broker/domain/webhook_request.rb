require 'pact_broker/build_http_options'
require 'pact_broker/domain/webhook_request_header'
require 'pact_broker/domain/webhook_execution_result'
require 'pact_broker/logging'
require 'pact_broker/messages'
require 'net/http'
require 'pact_broker/webhooks/render'
require 'pact_broker/api/pact_broker_urls'
require 'pact_broker/build_http_options'
require 'cgi'

module PactBroker

  module Domain

    class WebhookRequestError < StandardError

      def initialize message, response
        super message
        @response = response
      end

    end

    class WebhookRequest

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
        @headers = attributes[:headers] || {}
        @body = attributes[:body]
        @uuid = attributes[:uuid]
      end

      def description
        "#{method.upcase} #{URI(url).host}"
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

      def execute pact, verification, options = {}
        logs = StringIO.new
        execution_logger = Logger.new(logs)
        begin
          execute_and_build_result(pact, verification, options, logs, execution_logger)
        rescue StandardError => e
          handle_error_and_build_result(e, options, logs, execution_logger)
        end
      end

      private

      def execute_and_build_result pact, verification, options, logs, execution_logger
        uri = build_uri(pact, verification)
        req = build_request(uri, pact, verification, execution_logger)
        response = do_request(uri, req)
        log_response(response, execution_logger, options)
        result = WebhookExecutionResult.new(response, logs.string)
        log_completion_message(options, execution_logger, result.success?)
        result
      end

      def handle_error_and_build_result e, options, logs, execution_logger
        log_error(e, execution_logger, options)
        log_completion_message(options, execution_logger, false)
        WebhookExecutionResult.new(nil, logs.string, e)
      end

      def build_request uri, pact, verification, execution_logger
        req = http_request(uri)
        execution_logger.info "HTTP/1.1 #{method.upcase} #{url_with_credentials(pact, verification)}"

        headers_to_log = redacted_headers
        headers.each_pair do | name, value |
          execution_logger.info "#{name}: #{headers_to_log[name]}"
          req[name] = value
        end

        req.basic_auth(username, password) if username

        unless body.nil?
          req.body = PactBroker::Webhooks::Render.call(String === body ? body : body.to_json, pact, verification)
        end

        execution_logger.info(req.body) if req.body
        req
      end

      def do_request uri, req
        logger.info "Making webhook #{uuid} request #{to_s}"
        options = PactBroker::BuildHttpOptions.call(uri)
        Net::HTTP.start(uri.hostname, uri.port, :ENV, options) do |http|
          http.request req
        end
      end

      def log_response response, execution_logger, options
        log_response_to_application_logger(response)
        if options[:show_response]
          log_response_to_execution_logger(response, execution_logger)
        else
          execution_logger.info response_body_hidden_message
        end
      end

      def response_body_hidden_message
        PactBroker::Messages.message('messages.response_body_hidden')
      end

      def log_response_to_application_logger response
        logger.info "Received response for webhook #{uuid} status=#{response.code}"
        logger.debug "headers=#{response.to_hash}"
        logger.debug "body=#{response.body}"
      end

      def log_response_to_execution_logger response, execution_logger
        execution_logger.info "HTTP/#{response.http_version} #{response.code} #{response.message}"
        response.each_header do | header |
          execution_logger.info "#{header.split("-").collect(&:capitalize).join('-')}: #{response[header]}"
        end

        safe_body = nil

        if response.body
          safe_body = response.body.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
          if response.body != safe_body
            execution_logger.debug "Note that invalid UTF-8 byte sequences were removed from response body before saving the logs"
          end
        end
        execution_logger.info safe_body
      end

      def log_completion_message options, execution_logger, success
        if options[:success_log_message] && success
          execution_logger.info(options[:success_log_message])
          logger.info(options[:success_log_message])
        end

        if options[:failure_log_message] && !success
          execution_logger.info(options[:failure_log_message])
          logger.info(options[:failure_log_message])
        end
      end

      def log_error e, execution_logger, options
        logger.error "Error executing webhook #{uuid} #{e.class.name} - #{e.message} #{e.backtrace.join("\n")}"

        if options[:show_response]
          execution_logger.error "Error executing webhook #{uuid} #{e.class.name} - #{e.message}"
        else
          execution_logger.error "Error executing webhook #{uuid}. #{response_body_hidden_message}"
        end
      end

      def to_s
        "#{method.upcase} #{url}, username=#{username}, password=#{display_password}, headers=#{redacted_headers}, body=#{body}"
      end

      def http_request(uri)
        Net::HTTP.const_get(method.capitalize).new(uri)
      end

      def build_uri(pact, verification)
        URI(PactBroker::Webhooks::Render.call(url, pact, verification){ | value | CGI::escape(value)} )
      end

      def url_with_credentials pact, verification
        u = build_uri(pact, verification)
        u.userinfo = "#{CGI::escape username}:#{display_password}" if username
        u
      end
    end
  end
end

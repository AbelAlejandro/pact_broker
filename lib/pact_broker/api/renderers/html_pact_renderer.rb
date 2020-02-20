require 'pact/consumer_contract'
require 'pact/reification'
require 'redcarpet'
require 'pact/doc/markdown/consumer_contract_renderer'
require 'pact_broker/api/pact_broker_urls'
require 'pact_broker/logging'

module PactBroker
  module Api
    module Renderers
      class HtmlPactRenderer

        class NotAPactError < StandardError; end

        include PactBroker::Logging

        def self.call pact, options = {}
          new(pact, options).call
        end

        def initialize pact, options = {}
          @json_content = pact.json_content
          @pact = pact
          @options = options
        end

        def call
          "<html>
            <head>#{head}</head>
            <body>
              #{pact_metadata}#{html}
            </body>
          </html>"
        end

        private

        def head
         "<title>#{title}</title>
          <link rel='stylesheet' type='text/css' href='/stylesheets/github.css'>
          <link rel='stylesheet' type='text/css' href='/stylesheets/pact.css'>
          <link rel='stylesheet' type='text/css' href='/stylesheets/github-json.css'>
          <link rel='stylesheet' type='text/css' href='/css/bootstrap.min.css'>
          <link rel='stylesheet' type='text/css' href='/stylesheets/material-menu.css'>
          <link rel='stylesheet' type='text/css' href='/stylesheets/jquery-confirm.min.css'>
          <script src='/javascripts/highlight.pack.js'></script>
          <script src='/javascripts/jquery-3.3.1.min.js'></script>
          <script src='/js/bootstrap.min.js'></script>
          <script src='/javascripts/material-menu.js'></script>
          <script src='/javascripts/pact.js'></script>
          <script src='/javascripts/jquery-confirm.min.js'></script>
          <script>hljs.initHighlightingOnLoad();</script>"
        end

        def pact_metadata
          "<div class='pact-metadata'>
            <ul>
              #{badge_list_item}
              #{badge_markdown_item}
              <li>
                <span class='name'>#{@pact.consumer.name} version:</span>
                <span class='value'>#{@pact.consumer_version_number}#{tags}</span>
              </li>
              <li>
                <span class='name' title='#{published_date}'>Date published:</span>
                <span class='value' title='#{published_date}'>#{published_date_in_words}</span>
              </li>
              <li>
                <a href=\"#{json_url}\">View in API Browser</a>
              </li>
              <li>
                <a href=\"#{matrix_url}\">View Matrix</a>
              </li>
              <li>
                <a href=\"/\">Home</a>
              </li>
              <li>
                <span data-consumer-name=\"#{@pact.consumer.name}\"
                      data-provider-name=\"#{@pact.provider.name}\"
                      data-consumer-version-number=\"#{@pact.consumer_version_number}\"
                      data-pact-url=\"#{pact_url}\"
                      class='more-options glyphicon glyphicon-option-horizontal'
                      aria-hidden='true'></span>
              </li>
            </ul>
          </div>"
        end

        def badge_list_item
            "<li class='pact-badge'>
              <img src='#{badge_url}'/>
            </li>
            "
        end

        def badge_markdown_item
          "<li class='pact-badge-markdown' style='display:none'>
              <textarea rows='3' cols='100'>#{badge_markdown}</textarea>
          </li>"
        end

        def badge_markdown
          warning = if badges_protected?
            "If the broker is protected by authentication, set `enable_public_badge_access` to true in the configuration to enable badges to be embedded in a markdown file.\n"
          else
            ""
          end
          "#{warning}[![#{@pact.consumer.name}/#{@pact.provider.name} Pact Status](#{badge_url})](#{badge_target_url})"
        end

        def badges_protected?
          !PactBroker.configuration.enable_public_badge_access
        end

        def base_url
          @options[:base_url] || ''
        end

        def title
          "Pact between #{@pact.consumer.name} and #{@pact.provider.name}"
        end

        def published_date
          @pact.created_at.to_time.localtime.to_datetime.strftime("%a %d %b %Y, %l:%M%P %:z")
        end

        def published_date_in_words
          PactBroker::DateHelper.distance_of_time_in_words(@pact.created_at.to_time, DateTime.now) + " ago"
        end

        def json_url
          PactBroker::Api::PactBrokerUrls.hal_browser_url pact_url
        end

        def pact_url
          PactBroker::Api::PactBrokerUrls.pact_url base_url, @pact
        end

        def matrix_url
          PactBroker::Api::PactBrokerUrls.matrix_for_pacticipant_version_url(@pact.consumer_version, base_url)
        end

        def latest_pact_url
          PactBroker::Api::PactBrokerUrls.latest_pact_url base_url, @pact
        end

        def badge_target_url
          base_url
        end

        def badge_url
          @options[:badge_url]
        end

        def tags
          if @pact.consumer_version_tag_names.any?
            " (#{@pact.consumer_version_tag_names.join(", ")})"
          else
            ""
          end
        end

        def markdown
          Pact::Doc::Markdown::ConsumerContractRenderer.call consumer_contract
        rescue StandardError
          heading = "### A contract between #{@pact.consumer.name} and #{@pact.provider.name}"
          warning = "_Note: this contract could not be parsed to a v1 or v2 Pact, showing raw content instead._"
          pretty_json = JSON.pretty_generate(@pact.content_hash)
          "#{heading}\n#{warning}\n```json\n#{pretty_json}\n```\n"
        end

        def html
          Redcarpet::Markdown.new(Redcarpet::Render::HTML, :fenced_code_blocks => true, :lax_spacing => true).render(markdown)
        end

        def consumer_contract
          Pact::ConsumerContract.from_json(@json_content)
        rescue => e
          logger.info "Could not parse the following content to a Pact due to #{e.class} #{e.message}, showing raw content instead: #{@json_content}"
          raise NotAPactError
        end
      end
    end
  end
end

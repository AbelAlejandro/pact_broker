module PactBroker
  module Webhooks
    class Render

      TEMPLATE_PARAMETER_REGEXP = /\$\{pactbroker\.[^\}]+\}/

      def self.call(template, pact, trigger_verification = nil, &escaper)
        base_url = PactBroker.configuration.base_url
        verification = trigger_verification || (pact && pact.latest_verification)
        params = {
          '${pactbroker.pactUrl}' => pact ? PactBroker::Api::PactBrokerUrls.pact_url(base_url, pact) : "",
          '${pactbroker.verificationResultUrl}' => verification_url(verification),
          '${pactbroker.consumerVersionNumber}' => pact ? pact.consumer_version_number : "",
          '${pactbroker.providerVersionNumber}' => verification ? verification.provider_version_number : "",
          '${pactbroker.providerVersionTags}' => provider_version_tags(verification),
          '${pactbroker.consumerVersionTags}' => consumer_version_tags(pact),
          '${pactbroker.consumerName}' => pact ? pact.consumer_name : "",
          '${pactbroker.providerName}' => pact ? pact.provider_name : "",
          '${pactbroker.githubVerificationStatus}' => github_verification_status(verification)
        }

        if escaper
          params.keys.each do | key |
            params[key] = escaper.call(params[key])
          end
        end

        params.inject(template) do | template, (key, value) |
          template.gsub(key, value)
        end
      end

      def self.github_verification_status verification
        if verification
          verification.success ? "success" : "failure"
        else
          "pending"
        end
      end

      def self.verification_url verification
        if verification
          PactBroker::Api::PactBrokerUrls.verification_url(verification, PactBroker.configuration.base_url)
        else
          ""
        end
      end

      def self.consumer_version_tags pact
        if pact
          pact.consumer_version.tags.collect(&:name).join(", ")
        else
          ""
        end
      end

      def self.provider_version_tags verification
        if verification
          verification.provider_version.tags.collect(&:name).join(", ")
        else
          ""
        end
      end
    end
  end
end

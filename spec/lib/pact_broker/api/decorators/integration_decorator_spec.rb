require 'pact_broker/api/decorators/integration_decorator'
require 'pact_broker/integrations/integration'

module PactBroker
  module Api
    module Decorators
      describe IntegrationDecorator do
        before do
          allow(integration_decorator).to receive(:dashboard_url_for_integration).and_return("/dashboard")
        end

        let(:integration) do
          instance_double(PactBroker::Integrations::Integration,
            consumer: consumer,
            provider: provider
          )
        end
        let(:consumer) { double("consumer", name: "the consumer") }
        let(:provider) { double("provider", name: "the provider") }
        let(:options) { { user_options: { base_url: 'http://example.org' } } }
        let(:expected_hash) do
          {
            "consumer" => {
              "name" => "the consumer"
            },
            "provider" => {
              "name" => "the provider"
            },
            "_links" => {
              "pb:dashboard" => {
                "href" => "/dashboard"
              }
            }
          }
        end

        let(:integration_decorator) { IntegrationDecorator.new(integration) }
        let(:json) { integration_decorator.to_json(options) }
        subject { JSON.parse(json) }

        it "generates a hash" do
          expect(subject).to match_pact expected_hash
        end

        it "generates the correct link for the dashboard" do
          expect(integration_decorator).to receive(:dashboard_url_for_integration).with(
            "the consumer",
            "the provider",
            "http://example.org"
          )
          subject
        end
      end
    end
  end
end

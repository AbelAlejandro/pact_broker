require 'pact_broker/api/decorators/dashboard_decorator'

module PactBroker
  module Api
    module Decorators
      describe DashboardDecorator do
        let(:index_item) do
          instance_double('PactBroker::Domain::IndexItem',
            consumer: consumer,
            provider: provider,
            consumer_name: consumer.name,
            provider_name: provider.name,
            latest_pact: pact,
            latest_verification: verification,
            provider_version: provider_version,
            consumer_version: consumer_version,
            last_webhook_execution_date: last_webhook_execution_date,
            webhook_status: 'blah',
            verification_status: 'wiffle',
            provider_version_number: provider_version.number,
            consumer_version_number: consumer_version.number
          )
        end
        let(:consumer) { instance_double('PactBroker::Domain::Pacticipant', name: 'Foo') }
        let(:provider) { instance_double('PactBroker::Domain::Pacticipant', name: 'Bar') }
        let(:pact) { instance_double('PactBroker::Domain::Pact', created_at: DateTime.new(2018)) }
        let(:verification) { instance_double('PactBroker::Domain::Verification', success: true, created_at: DateTime.new(2018)) }
        let(:consumer_version) { instance_double('PactBroker::Domain::Version', number: '1', pacticipant: consumer) }
        let(:provider_version) { instance_double('PactBroker::Domain::Version', number: '2', pacticipant: provider) }
        let(:last_webhook_execution_date) { Date.new(2018) }
        let(:base_url) { 'http://example.org' }
        let(:options) { { user_options: { base_url: base_url } } }
        let(:dashboard_json) { DashboardDecorator.new([index_item]).to_json(options) }

        before do
          allow_any_instance_of(DashboardDecorator).to receive(:pact_url).with(base_url, pact).and_return('pact_url')
          allow_any_instance_of(DashboardDecorator).to receive(:verification_url).with(verification, base_url).and_return('verification_url')
          allow_any_instance_of(DashboardDecorator).to receive(:pacticipant_url).with(base_url, consumer).and_return('consumer_url')
          allow_any_instance_of(DashboardDecorator).to receive(:pacticipant_url).with(base_url, provider).and_return('provider_url')
          allow_any_instance_of(DashboardDecorator).to receive(:version_url).with(base_url, consumer_version).and_return('consumer_version_url')
          allow_any_instance_of(DashboardDecorator).to receive(:webhooks_status_url).with(consumer, provider, base_url).and_return('webhooks_status_url')
        end

        let(:expected_hash) { JSON.parse(File.read('spec/fixtures/dashboard.json')) }

        subject { JSON.parse(dashboard_json) }

        it "creates some json" do
          expect(subject).to match_pact(expected_hash, {allow_unexpected_keys: false})
        end

        context "when the pact has never been verified" do
          let(:verification) { nil }

          it "has a null last verification and provider version" do
            expected_hash['items'][0]['latestVerificationResult'] = nil
            expected_hash['items'][0]['provider']['version'] = nil
            expect(subject).to match_pact(expected_hash, {allow_unexpected_keys: false})
          end
        end

        context "when no webhooks have been executed" do
          let(:last_webhook_execution_date) { nil }

          it "has a null latestWebhookExecution" do
            expected_hash['items'][0]['latestWebhookExecution'] = nil
            expect(subject).to match_pact(expected_hash, {allow_unexpected_keys: false})
          end
        end
      end
    end
  end
end

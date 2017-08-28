require 'pact_broker/api/decorators/pact_webhooks_status_decorator'

module PactBroker
  module Api
    module Decorators
      describe PactWebhooksStatusDecorator do

        let(:user_options) do
          {consumer: 'Foo', provider: 'Bar', resource_url: 'http://example.org/foo', base_url: 'http://example.org'}
        end

        let(:triggered_webhook) do
          double('PactBroker::Webhooks::TriggeredWebhook',
            trigger_type: PactBroker::Webhooks::TriggeredWebhook::TRIGGER_TYPE_PUBLICATION,
            status: status,
            failure?: failure,
            retrying?: retrying,
            trigger_uuid: '1234',
            webhook_uuid: '4321',
            request_description: "GET http://foo",
            pact_publication: pact,
            created_at: DateTime.new(2017),
            updated_at: DateTime.new(2017)
          )
        end

        let(:pact) do
          double('pact',
            provider: double(name: 'provider'),
            consumer: double(name: 'consumer'),
            consumer_version_number: '1',
            name: 'foo '
          )
        end
        let(:failure) { false }
        let(:retrying) { false }
        let(:status) { PactBroker::Webhooks::TriggeredWebhook::STATUS_SUCCESS }
        let(:logs_url) { "http://example.org/webhooks/4321/trigger/1234/logs" }

        let(:json) do
          PactWebhooksStatusDecorator.new([triggered_webhook]).to_json(user_options: user_options)
        end

        subject { JSON.parse json, symbolize_names: true }

        it "includes a list of triggered webhooks" do
          expect(subject[:_embedded][:triggeredWebhooks]).to be_instance_of(Array)
        end

        it "includes a link to the logs" do
          expect(subject[:_embedded][:triggeredWebhooks][0][:_links][:logs][:href]).to eq logs_url
        end

        it "includes the triggered webhooks properties" do
          expect(subject[:_embedded][:triggeredWebhooks].first).to include(status: 'success', triggerType: 'pact_publication')
        end

        it "includes a link to the consumer" do
          expect(subject[:_links][:'pb:consumer']).to_not be nil
        end

        it "includes a link to the provider" do
          expect(subject[:_links][:'pb:provider']).to_not be nil
        end

        it "includes a link to the pact" do
          expect(subject[:_links][:'pb:pact-version']).to_not be nil
        end

        it "includes a summary of the triggered webhook statuses" do
          expect(subject[:counts]).to eq({successful: 1, failed: 0})
        end

        context "when there is a failure" do
          let(:status) { PactBroker::Webhooks::TriggeredWebhook::STATUS_FAILURE }
          let(:failure) { true }

          it "includes a link to the error logs" do
            expect(subject[:_links][:'pb:error-logs'][0][:href]).to eq logs_url
          end

          it "has a failed count of 1" do
            expect(subject[:counts]).to eq({successful: 0, failed: 1})
          end
        end

        context "when there is a retry" do
          let(:status) { PactBroker::Webhooks::TriggeredWebhook::STATUS_RETRYING }
          let(:retrying) { true }

          it "includes a link to the error logs" do
            expect(subject[:_links][:'pb:error-logs'][0][:href]).to eq logs_url
          end

          it "has a retrying count of 1" do
            expect(subject[:counts]).to eq({successful: 0, failed: 0, retrying: 1})
          end
        end

        context "when there is a not_run triggered webhook" do
          let(:status) { PactBroker::Webhooks::TriggeredWebhook::STATUS_NOT_RUN }

          it "does not include a link to the error logs" do
            expect(subject[:_links][:'pb:error-logs']).to be_empty
          end

          it "has a notRun count of 1" do
            expect(subject[:counts]).to eq({successful: 0, failed: 0, notRun: 1})
          end
        end
      end
    end
  end
end

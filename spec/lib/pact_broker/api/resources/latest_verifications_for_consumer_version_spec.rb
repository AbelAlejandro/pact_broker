require 'pact_broker/api/resources/latest_verifications_for_consumer_version'
require 'pact_broker/versions/service'

module PactBroker
  module Api
    module Resources

      describe LatestVerificationsForConsumerVersion do
        describe "GET" do
          let(:url) { '/pacts/consumer/Consumer/versions/1.2.3/verifications/latest' }
          let(:response_body) { JSON.parse(subject.body, {symbolize_names: true}) }
          let(:version) { double(:version) }

          subject { get url; last_response }

          before do
            allow(PactBroker::Versions::Service).to receive(:find_by_pacticipant_name_and_number).and_return(version)
          end

          it "looks up the consumer version" do
            expect(PactBroker::Versions::Service).to receive(:find_by_pacticipant_name_and_number).with(hash_including(consumer_name: 'Consumer', consumer_version_number: '1.2.3'))
            subject
          end

          context "when the consumer version exists" do
            let(:decorator) { double(:decorator, to_json: json) }
            let(:verifications) { double(:verifications) }
            let(:json) { {some: 'json'}.to_json }

            before do
              allow(PactBroker::Api::Decorators::VerificationsDecorator).to receive(:new).and_return(decorator)
              allow(PactBroker::Verifications::Service).to receive(:find_latest_verifications_for_consumer_version).and_return(verifications)
            end

            it { is_expected.to be_a_hal_json_success_response }

            it "finds the latest verifications for the consumer version" do
              expect(PactBroker::Verifications::Service).to receive(:find_latest_verifications_for_consumer_version).with(hash_including(consumer_name: 'Consumer', consumer_version_number: '1.2.3'))
              subject
            end

            it "serialises the verifications" do
              expect(PactBroker::Api::Decorators::VerificationsDecorator).to receive(:new).with(verifications)
              expect(decorator).to receive(:to_json).with(user_options: {base_url: 'http://example.org'})
              subject
            end

            it "returns the serialised verifications in the response" do
              expect(subject.body).to eq(json)
            end
          end

          context "when the consumer version does not exist" do
            let(:version) { nil }

            it { is_expected.to be_a_404_response }
          end

        end
      end
    end
  end
end

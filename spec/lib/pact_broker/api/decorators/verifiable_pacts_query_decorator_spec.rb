require 'pact_broker/api/decorators/verifiable_pacts_query_decorator'

module PactBroker
  module Api
    module Decorators
      describe VerifiablePactsQueryDecorator do

        let(:provider_version_tags) { %w[dev] }

        subject { VerifiablePactsQueryDecorator.new(OpenStruct.new).from_hash(params)  }

        context "when parsing JSON params" do
          let(:params) do
            {
              "providerVersionTags" => provider_version_tags,
              "consumerVersionSelectors" => consumer_version_selectors
            }
          end

          let(:consumer_version_selectors) do
            [{"tag" => "dev", "ignored" => "foo", "latest" => true}]
          end

          context "when latest is not specified" do
            let(:consumer_version_selectors) do
              [{"tag" => "dev"}]
            end

            it "defaults to nil" do
              expect(subject.consumer_version_selectors.first.latest).to be nil
            end
          end

          it "parses the latest as a boolean" do
            expect(subject.consumer_version_selectors.first.latest).to be true
          end

          context "when there are no consumer_version_selectors" do
            let(:params) { {} }

            it "returns an empty array" do
              expect(subject.consumer_version_selectors).to eq []
            end
          end

          context "when there are no provider_version_tags" do
            let(:params) { {} }

            it "returns an empty array" do
              expect(subject.provider_version_tags).to eq []
            end
          end
        end

        context "when parsing query string params" do
          let(:params) do
            {
              "provider_version_tags" => provider_version_tags,
              "consumer_version_selectors" => consumer_version_selectors
            }
          end

          let(:consumer_version_selectors) do
            [{"tag" => "dev", "latest" => "true"}]
          end

          it "parses the provider_version_tags" do
            expect(subject.provider_version_tags).to eq provider_version_tags
          end

          it "parses a string 'latest' to a boolean" do
            expect(subject.consumer_version_selectors.first.latest).to be true
          end
        end

        context "when specifying include_wip_pacts_since" do
          let(:params) do
            {
              "include_wip_pacts_since" => "2013-02-13T20:04:45.000+11:00"
            }
          end

          it "parses the date" do
            expect(subject.include_wip_pacts_since).to eq DateTime.parse("2013-02-13T20:04:45.000+11:00")
          end
        end
      end
    end
  end
end

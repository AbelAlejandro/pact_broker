require "pact_broker/api/contracts/verifiable_pacts_json_query_schema"

module PactBroker
  module Api
    module Contracts
      describe VerifiablePactsJSONQuerySchema do
        ALL_PROPERTIES = {
          mainBranch: true,
          tag: "tag",
          branch: "branch",
          latest: true,
          fallbackTag: "fallbackTag",
          fallbackBranch: "fallbackBranch",
          environment: "environment",
          deployed: true,
          released: true,
          deployedOrReleased: true,
          consumer: "consumer"
        }

        VALID_KEY_COMBINATIONS = [
          [:mainBranch],
          [:tag],
          [:tag, :latest],
          [:tag, :latest, :fallbackTag],
          [:branch],
          [:branch, :latest],
          [:branch, :latest, :fallbackBranch],
          [:branch, :fallbackBranch],
          [:environment],
          [:environment, :deployed],
          [:environment, :released],
          [:deployed],
          [:released],
          [:deployedOrReleased],
          [:environment, :deployedOrReleased]
        ]

        VALID_KEY_COMBINATIONS.each do | valid_key_combination |
          selector = ALL_PROPERTIES.slice(*valid_key_combination)

          describe "with #{selector}" do
            before do
              allow(PactBroker::Deployments::EnvironmentService).to receive(:find_by_name).and_return(double("environment"))
            end

            it "is valid" do
              params = { consumerVersionSelectors: [selector] }
              expect(VerifiablePactsJSONQuerySchema.(params)).to be_empty
            end

            extra_keys = ALL_PROPERTIES.keys - valid_key_combination - [:consumer]
            extra_keys.each do | extra_key |
              selector_with_extra_key = selector.merge(extra_key => ALL_PROPERTIES[extra_key])
              expect_to_be_valid = !!VALID_KEY_COMBINATIONS.find{ | k | k.sort == selector_with_extra_key.keys.sort }
              params = { consumerVersionSelectors: [selector_with_extra_key] }

              describe "with #{selector_with_extra_key}" do
                if expect_to_be_valid
                  it "is valid" do
                    expect(VerifiablePactsJSONQuerySchema.(params)).to be_empty
                  end
                else
                  it "is not valid" do
                    expect(VerifiablePactsJSONQuerySchema.(params)).to_not be_empty
                  end
                end
              end

              selector_with_consumer = selector.merge(consumer: ALL_PROPERTIES[:consumer])

              describe "with #{selector_with_consumer}" do
                it "is valid" do
                  params = { consumerVersionSelectors: [selector_with_consumer] }

                  expect(VerifiablePactsJSONQuerySchema.(params).empty?).to be true
                end
              end
            end
          end
        end
      end
    end
  end
end

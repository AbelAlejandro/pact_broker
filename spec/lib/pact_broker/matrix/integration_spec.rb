require 'pact_broker/matrix/service'

module PactBroker
  module Matrix
    describe Service do
      let(:td) { TestDataBuilder.new }

      describe "find" do
        subject { Service.find(selectors, options) }

        # Useful for eyeballing the messages to make sure they read nicely
        # after do
        #   require 'pact_broker/api/decorators/reason_decorator'
        #   subject.deployment_status_summary.reasons.each do | reason |
        #     puts reason
        #     puts PactBroker::Api::Decorators::ReasonDecorator.new(reason).to_s
        #   end
        # end

        let(:options) { {} }

        describe "find" do
          let(:selectors) do
            [ { pacticipant_name: "foo" } ]
          end

          let(:options) do
            { latest: true, tag: "prod", latestby: "cvp" }
          end

          before do
            td.create_pact_with_hierarchy("foo", "1", "bar")
              .create_verification(provider_version: "2", tag_names: ["prod"])
          end

          it "returns a QueryResultsWithDeploymentStatusSummary" do
            expect(subject.rows).to be_a(Array)
            expect(subject.selectors).to be selectors
            expect(subject.options).to be options
            expect(subject.resolved_selectors).to be_a(Array)
            expect(subject.resolved_selectors.count).to eq 2
            expect(subject.integrations.count).to eq 1
            expect(subject.deployment_status_summary).to be_a(DeploymentStatusSummary)
          end
        end

        describe "when deploying a version of a provider with multiple versions of a consumer in production that is missing a verification for the latest prod version" do
          before do
            td.create_pact_with_hierarchy("Foo", "1", "Bar")
              .create_consumer_version_tag("prod")
              .create_verification(provider_version: "10", tag_names: ["test"])
              .create_consumer_version("2", tag_names: ["prod"])
              .create_pact
          end

          let(:selectors) { [{ pacticipant_name: "Bar", latest: true, tag: "test" }]}
          let(:options) { { tag: "prod", latestby: "cvp" } }

          it "does not allow the consumer to be deployed" do
            expect(subject.deployment_status_summary).to_not be_deployable
          end
        end

        describe "when deploying a consumer that has not been verified by any providers" do
          before do
            td.create_pact_with_hierarchy("Foo", "1", "Bar")
              .create_provider("Baz")
              .create_pact
          end
          let(:selectors) do
            [ { pacticipant_name: "Foo", pacticipant_version_number: "1" } ]
          end

          it "returns 2 integrations" do
            expect(subject.integrations.size).to eq 2
          end

          it "but cannot resolve selectors for the providers" do
            expect(subject.resolved_selectors.size).to eq 1
          end

          it "does not allow the consumer to be deployed" do
            expect(subject.deployment_status_summary).to_not be_deployable
          end
        end

        describe "when deploying a consumer that has two providers in prod, but it is not verified by one of the prod provider versions, pact_broker-client issue #33" do
          before do
            td.create_pact_with_hierarchy("Foo", "3.0.0", "Bar")
              .create_verification(provider_version: "10.0.0", tag_names: ["prod"])
              .create_provider("Baz")
              .create_pact
              .create_verification(provider_version: "20", tag_names:["prod"])
              .create_consumer_version("2.0.0")
              .use_provider("Bar")
              .create_pact
              .create_verification(provider_version: "11.0.0", tag_names: ["prod"])
          end

          let(:selectors) do
            [ { pacticipant_name: "Foo", pacticipant_version_number: "3.0.0" } ]
          end

          let(:options) { {latest: true, tag: "prod", latestby: "cvp"} }

          it "returns 2 integrations" do
            expect(subject.integrations.size).to eq 2
          end

          it "returns 1 row with a verification" do
            expect(subject.rows.select(&:has_verification?).size).to eq 1
          end

          it "returns 1 row without a verification" do
            expect(subject.rows.reject(&:has_verification?).size).to eq 1
          end

          it "does not allow the consumer to be deployed" do
            expect(subject.deployment_status_summary).to_not be_deployable
          end
        end

        describe "when deploying an old version of a consumer that has added a new provider since that version" do
          before do
            td.create_pact_with_hierarchy("Foo", "1", "Bar")
              .create_verification(provider_version: "2")
              .create_consumer_version("2")
              .create_pact
              .create_verification(provider_version: "3")
              .create_provider("Wiffle")
              .create_pact
              .create_verification(provider_version: "10")
          end

          let(:selectors) do
            [ { pacticipant_name: "Foo", pacticipant_version_number: "1" } ]
          end

          it "allows the old version of the consumer to be deployed" do
            expect(subject.deployment_status_summary).to be_deployable
          end
        end

        describe "when the specified version does not exist" do
          before do
            td.create_pact_with_hierarchy("Foo", "1", "Bar")
          end

          let(:selectors) do
            [ { pacticipant_name: "Bar", pacticipant_version_number: "5" } ]
          end

          it "does not allow the app to be deployed" do
            expect(subject.deployment_status_summary).to_not be_deployable
          end
        end

        describe "when deploying a provider to prod for the first time and the consumer is not yet deployed" do
          before do
            td.create_pact_with_hierarchy("Foo", "1", "Bar")
            .create_verification(provider_version: "2")
          end

          let(:selectors) do
            [ { pacticipant_name: "Bar", pacticipant_version_number: "2" } ]
          end

          let(:options) do
            { latest: true, tag: "prod", latestby: "cvp" }
          end

          subject { Service.find(selectors, options) }

          it "allows the app to be deployed" do
            expect(subject.deployment_status_summary).to be_deployable
          end
        end

        describe "when deploying a consumer to prod for the first time and the provider is not yet deployed" do
          before do
            td.create_pact_with_verification("Foo", "1", "Bar", "2")
          end

          let(:selectors) do
            [ { pacticipant_name: "Foo", pacticipant_version_number: "1" } ]
          end

          let(:options) do
            { latest: true, tag: "prod", latestby: "cvp" }
          end

          it "does not allow the app to be deployed" do
            expect(subject.deployment_status_summary).to_not be_deployable
          end
        end

        describe "when deploying an app that is both a consumer and a provider to prod for the first time and the downstream provider is not yet deployed" do
          before do
            td.create_pact_with_verification("Foo", "1", "Bar", "2")
            .use_consumer("Bar")
            .use_consumer_version("2")
            .create_provider("Baz")
            .create_pact
          end

          let(:selectors) do
            [ { pacticipant_name: "Bar", pacticipant_version_number: "2" } ]
          end

          let(:options) do
            { latest: true, tag: "prod", latestby: "cvp" }
          end

          it "does not allow the app to be deployed" do
            expect(subject.deployment_status_summary).to_not be_deployable
          end
        end

        describe "when deploying an app that is both a consumer and a provider to prod for the first time and the downstream provider has been deployed" do
          before do
            # Foo v1 => Bar v2
            # Bar v2 => Baz v4 (prod)
            td.create_pact_with_verification("Foo", "1", "Bar", "2")
            .use_consumer("Bar")
            .use_consumer_version("2")
            .create_provider("Baz")
            .create_pact
            .create_verification(provider_version: "4", tag_names: "prod")
          end

          let(:selectors) do
            [ { pacticipant_name: "Bar", pacticipant_version_number: "2" } ]
          end

          # Deploy Bar v2 to prod
          let(:options) do
            { latest: true, tag: "prod", latestby: "cvp" }
          end

          it "allows the app to be deployed" do
            expect(subject.deployment_status_summary).to be_deployable
          end
        end

        describe "when two applications have pacts with each other (nureva use case)" do
          # ServiceA v 1 has been verified by ServiceB v 100
          # but ServiceB v 100 has only been verified by ServiceA v 99.
          # It's missing a verification from ServiceA v1.
          before do
            td.create_pact_with_verification("ServiceB", "100", "ServiceA", "99")
              .create_pact_with_verification("ServiceA", "1", "ServiceB", "100")
          end

          context "when both application versions are specified explictly" do
            let(:selectors) do
              [
                { pacticipant_name: "ServiceA", pacticipant_version_number: "1" },
                { pacticipant_name: "ServiceB", pacticipant_version_number: "100" }
              ]
            end

            let(:options) { { latestby: "cvpv" } }

            it "does not allow the two apps to be deployed together" do
              expect(subject.deployment_status_summary).to_not be_deployable
            end
          end

          context "when only one application is specified" do
            let(:selectors) do
              [
                { pacticipant_name: "ServiceB", pacticipant_version_number: "100" }
              ]
            end

            let(:options) { { latestby: "cvp", latest: true } }

            it "does not allow the two apps to be deployed together" do
              expect(subject.deployment_status_summary).to_not be_deployable
            end
          end
        end
      end
    end
  end
end

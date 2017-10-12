require 'spec_helper'
require 'pact_broker/ui/view_models/relationship'

module PactBroker
  module UI
    module ViewDomain
      describe Relationship do

        let(:consumer) { instance_double("PactBroker::Domain::Pacticipant", name: 'Consumer Name')}
        let(:provider) { instance_double("PactBroker::Domain::Pacticipant", name: 'Provider Name')}
        let(:latest_pact) { instance_double("PactBroker::Domain::Pact") }
        let(:latest_verification) { instance_double("PactBroker::Domain::Verification") }
        let(:domain_relationship) { PactBroker::Domain::Relationship.new(consumer, provider, latest_pact, latest_verification)}

        subject { Relationship.new(domain_relationship) }

        its(:consumer_name) { should eq 'Consumer Name'}
        its(:provider_name) { should eq 'Provider Name'}
        its(:latest_pact_url) { should eq "/pacts/provider/Provider%20Name/consumer/Consumer%20Name/latest" }
        its(:consumer_group_url) { should eq "/groups/Consumer%20Name" }
        its(:provider_group_url) { should eq "/groups/Provider%20Name" }

        describe "verification_status" do
          let(:domain_relationship) do
            instance_double("PactBroker::Domain::Relationship",
              verification_status: verification_status,
              provider_name: "Foo",
              latest_verification_provider_version_number: "4.5.6")
          end
          let(:ever_verified) { true }
          let(:pact_changed) { false }
          let(:success) { true }

          subject { Relationship.new(domain_relationship) }

          context "when the pact has never been verified" do
            let(:verification_status) { :never }
            its(:verification_status) { is_expected.to eq "" }
            its(:warning?) { is_expected.to be false }
            its(:verification_tooltip) { is_expected.to eq nil }
          end

          context "when the pact has changed since the last successful verification" do
            let(:verification_status) { :stale }
            its(:verification_status) { is_expected.to eq "warning" }
            its(:warning?) { is_expected.to be true }
            its(:verification_tooltip) { is_expected.to eq "Pact has changed since last successful verification by Foo (v4.5.6)" }
          end

          context "when the pact has not changed since the last successful verification" do
            let(:verification_status) { :success }
            its(:verification_status) { is_expected.to eq "success" }
            its(:warning?) { is_expected.to be false }
            its(:verification_tooltip) { is_expected.to eq "Successfully verified by Foo (v4.5.6)" }
          end

          context "when the pact verification failed" do
            let(:verification_status) { :failed }
            its(:verification_status) { is_expected.to eq "danger" }
            its(:warning?) { is_expected.to be false }
            its(:verification_tooltip) { is_expected.to eq "Verification by Foo (v4.5.6) failed" }
          end
        end

        describe "webhooks" do
          let(:domain_relationship) do
            instance_double("PactBroker::Domain::Relationship",
              webhook_status: webhook_status,
              last_webhook_execution_date: DateTime.now - 1,
              latest_pact: double("pact", consumer: consumer, provider: provider)
            )
          end
          let(:webhook_status) { :none }

          subject { Relationship.new(domain_relationship) }

          context "when the webhooks_status is :none" do
            its(:webhook_label) { is_expected.to eq "Create" }
            its(:webhook_status) { is_expected.to eq "" }
            its(:webhook_url) { is_expected.to end_with "/webhooks/provider/Provider%20Name/consumer/Consumer%20Name"}
          end

          context "when the webhooks_status is :success" do
            let(:webhook_status) { :success }
            its(:webhook_label) { is_expected.to eq "1 day ago" }
            its(:webhook_status) { is_expected.to eq "success" }
            its(:webhook_url) { is_expected.to end_with "/webhooks/provider/Provider%20Name/consumer/Consumer%20Name/status"}
          end

          context "when the webhooks_status is :failure" do
            let(:webhook_status) { :failure }
            its(:webhook_label) { is_expected.to eq "1 day ago" }
            its(:webhook_status) { is_expected.to eq "danger" }
          end

          context "when the webhooks_status is :not_run" do
            let(:webhook_status) { :not_run }
            its(:webhook_label) { is_expected.to eq "Not run" }
            its(:webhook_status) { is_expected.to eq "" }
          end

          context "when the webhooks_status is :retrying" do
            let(:webhook_status) { :retrying }
            its(:webhook_label) { is_expected.to eq "Retrying" }
            its(:webhook_status) { is_expected.to eq "warning" }
          end
        end

        describe "<=>" do

          let(:relationship_model_4) { double("PactBroker::Domain::Relationship", consumer_name: "A", provider_name: "X") }
          let(:relationship_model_2) { double("PactBroker::Domain::Relationship", consumer_name: "a", provider_name: "y") }
          let(:relationship_model_3) { double("PactBroker::Domain::Relationship", consumer_name: "A", provider_name: "Z") }
          let(:relationship_model_1) { double("PactBroker::Domain::Relationship", consumer_name: "C", provider_name: "A") }

          let(:relationship_models) { [relationship_model_1, relationship_model_3, relationship_model_4, relationship_model_2] }
          let(:ordered_view_models) { [relationship_model_4, relationship_model_2, relationship_model_3, relationship_model_1] }

          let(:relationship_view_models) { relationship_models.collect{ |r| Relationship.new(r)} }

          it "sorts by consumer name then provider name" do
            expect(relationship_view_models.sort.collect{ |r| [r.consumer_name, r.provider_name]})
              .to eq([["A", "X"],["a","y"],["A","Z"],["C", "A"]])
          end

        end

      end
    end
  end
end
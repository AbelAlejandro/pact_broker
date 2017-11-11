require 'spec_helper'
require 'pact_broker/pacticipants/service'
require 'pact_broker/domain/tag'
require 'pact_broker/domain/pact'

module PactBroker

  module Pacticipants
    describe Service do

      let(:td) { TestDataBuilder.new }

      subject{ Service }

      describe ".update" do
        before do
          td.create_pacticipant("Foo")
        end

        let(:params) { { 'name' => 'Foo', 'repositoryUrl' => 'http://foo' } }

        subject { Service.update(params) }

        it "updates the repositoryUrl" do
          expect(subject.repository_url).to eq 'http://foo'
        end
      end

      describe ".messages_for_potential_duplicate_pacticipants" do

        let(:base_url) { 'http://example.org' }
        let(:fred_duplicates) { [double('Frederich pacticipant')] }
        let(:mary_dulicates) { [double('Marta pacticipant')] }

        before do
          allow(Service).to receive(:find_potential_duplicate_pacticipants).with("Fred").and_return(fred_duplicates)
          allow(Service).to receive(:find_potential_duplicate_pacticipants).with("Mary").and_return(mary_dulicates)
          allow(Messages).to receive(:potential_duplicate_pacticipant_message).and_return("message1", "message2")
        end

        subject { Service.messages_for_potential_duplicate_pacticipants ["Fred", "Mary"], base_url }

        it "finds the potential duplicates for each name" do
          expect(Service).to receive(:find_potential_duplicate_pacticipants).with("Fred")
          expect(Service).to receive(:find_potential_duplicate_pacticipants).with("Mary")
          subject
        end

        context "when there are potential duplicates" do

          it "creates a message for each dupliate" do
            expect(Messages).to receive(:potential_duplicate_pacticipant_message).with("Fred", fred_duplicates, base_url)
            expect(Messages).to receive(:potential_duplicate_pacticipant_message).with("Mary", mary_dulicates, base_url)
            subject
          end

          it "returns an array of messages" do
            expect(subject).to eq ["message1", "message2"]
          end
        end

        context "when there are no potential duplicates" do
          let(:fred_duplicates) { [] }
          let(:mary_dulicates) { [] }

          it "returns an empty array" do
            expect(subject).to eq []
          end
        end
      end

      describe ".find_potential_duplicate_pacticipants" do
        let(:pacticipant_name) { 'pacticipant_name' }
        let(:duplicates) { ["Fred", "Mary"] }
        let(:pacticipant_names) { double("pacticipant_names") }
        let(:fred) { double('fred pacticipant')}
        let(:mary) { double('mary pacticipant')}
        let(:pacticipant_repository) { instance_double(PactBroker::Pacticipants::Repository)}

        before do
          allow(PactBroker::Pacticipants::FindPotentialDuplicatePacticipantNames).to receive(:call).and_return(duplicates)
          allow(PactBroker::Pacticipants::Repository).to receive(:new).and_return(pacticipant_repository)
          allow(pacticipant_repository).to receive(:pacticipant_names).and_return(pacticipant_names)
          allow(pacticipant_repository).to receive(:find_by_name).with("Fred").and_return(fred)
          allow(pacticipant_repository).to receive(:find_by_name).with("Mary").and_return(mary)
        end

        it "finds all the pacticipant names" do
          expect(pacticipant_repository).to receive(:pacticipant_names)
          subject.find_potential_duplicate_pacticipants pacticipant_name
        end

        it "calculates the duplicates" do
          expect(PactBroker::Pacticipants::FindPotentialDuplicatePacticipantNames).to receive(:call).with(pacticipant_name, pacticipant_names)
          subject.find_potential_duplicate_pacticipants pacticipant_name
        end

        it "retrieves the pacticipants by name" do
          expect(pacticipant_repository).to receive(:find_by_name).with("Fred")
          expect(pacticipant_repository).to receive(:find_by_name).with("Mary")
          subject.find_potential_duplicate_pacticipants pacticipant_name
        end

        it "returns the duplicate pacticipants" do
          expect(subject.find_potential_duplicate_pacticipants(pacticipant_name)).to eq [fred, mary]
        end

        it "logs the names" do
          allow(PactBroker.logger).to receive(:info)
          expect(PactBroker.logger).to receive(:info).with(/pacticipant_name.*Fred, Mary/)
          subject.find_potential_duplicate_pacticipants pacticipant_name
        end
      end

      describe ".find_relationships" do
        let(:consumer) { instance_double("PactBroker::Domain::Pacticipant")}
        let(:provider) { instance_double("PactBroker::Domain::Pacticipant")}
        let(:pact) { instance_double("PactBroker::Domain::Pact", id: 1, consumer: consumer, provider: provider, consumer_name: 'foo', provider_name: 'bar', consumer_version_tag_names: [])}
        let(:verification) { instance_double("PactBroker::Domain::Verification")}
        let(:pacts) { [pact]}
        let(:webhooks) { [instance_double("PactBroker::Domain::Webhook")]}
        let(:triggered_webhooks) { [instance_double("PactBroker::Webhooks::TriggeredWebhook")] }

        before do
          allow_any_instance_of(PactBroker::Pacts::Repository).to receive(:find_latest_pacts).and_return(pacts)
          allow_any_instance_of(PactBroker::Pacts::Repository).to receive(:find_latest_pact).and_return(pact)
          allow(PactBroker::Verifications::Service).to receive(:find_latest_verification_for).and_return(verification)
          allow(PactBroker::Webhooks::Service).to receive(:find_by_consumer_and_provider).and_return(webhooks)
          allow(PactBroker::Webhooks::Service).to receive(:find_latest_triggered_webhooks).and_return(triggered_webhooks)
        end

        it "retrieves the webhooks for the pact" do
          expect(PactBroker::Webhooks::Service).to receive(:find_by_consumer_and_provider).with(consumer, provider)
          subject.find_relationships
        end

        it "retrieves the latest verification for the pact" do
          expect(PactBroker::Verifications::Service).to receive(:find_latest_verification_for).with(consumer, provider)
          subject.find_relationships
        end

        it "returns a list of relationships" do
          expect(subject.find_relationships).to eq([PactBroker::Domain::Relationship.create(consumer, provider, pact, true, verification, webhooks)])
        end
      end

      describe "find_relationships integration test" do
        context "when a prod pact exists and is not the latest version" do
          before do
            td.create_pact_with_hierarchy("Foo", "1.2.3", "Bar")
              .create_consumer_version_tag("prod")
              .create_consumer_version_tag("ignored")
              .create_verification(provider_version: "2.0.0")
              .create_consumer_version("1.2.4")
              .create_consumer_version_tag("also-ignored")
              .create_pact
              .create_verification(provider_version: "2.1.0")
          end

          let(:rows) { subject.find_relationships }

          it "returns both rows" do
            expect(rows.count).to eq 2
          end

          it "returns the latest row first" do
            expect(rows.first.consumer_version_number).to eq "1.2.4"
            expect(rows.last.consumer_version_number).to eq "1.2.3"
          end

          it "designates the first row as the latest row, and the second as not latest" do
            expect(rows.first.latest?).to be true
            expect(rows.last.latest?).to be false
          end

          it "doesn't return any tag names for the latest row" do
            expect(rows.first.tag_names).to eq []
          end

          it "includes the prod tag name for the prod row" do
            expect(rows.last.tag_names).to eq ['prod']
          end

          it "includes the latest overall verification for the latest pact" do
            expect(rows.first.latest_verification.provider_version_number).to eq '2.1.0'
          end

          it "includes the latest prod verification for the prod pact" do
            expect(rows.last.latest_verification.provider_version_number).to eq '2.0.0'
          end
        end

        context "when the prod version is the latest version" do
          before do
            td.create_pact_with_hierarchy("Foo", "1.2.3", "Bar")
              .create_consumer_version_tag("prod")
              .create_consumer_version_tag("ignored")
              .create_verification(provider_version: "2.0.0")
          end

          let(:rows) { subject.find_relationships }

          it "returns one row" do
            expect(rows.count).to eq 1
          end

          it "designates the row as the latest row" do
            expect(rows.first.latest?).to be true
          end

          it "includes the prod tag name for the row" do
            expect(rows.first.tag_names).to eq ['prod']
          end

          it "includes the latest overall verification for the latest pact" do
            expect(rows.first.latest_verification.provider_version_number).to eq '2.0.0'
          end
        end
      end

      describe "delete" do
        before do
          TestDataBuilder.new
            .create_consumer("Consumer")
            .create_consumer_version("2.3.4")
            .create_provider("Provider")
            .create_pact
            .create_consumer_version("1.2.3")
            .create_consumer_version_tag("prod")
            .create_pact
            .create_webhook
            .create_triggered_webhook
            .create_deprecated_webhook_execution
            .create_verification
        end

        let(:delete_consumer) { subject.delete "Consumer" }
        let(:delete_provider) { subject.delete "Provider" }

        context "deleting a consumer" do
          it "deletes the pacticipant" do
            expect{ delete_consumer }.to change{
                PactBroker::Domain::Pacticipant.all.count
              }.by(-1)
          end

          it "deletes the child versions" do
            expect{ delete_consumer }.to change{
              PactBroker::Domain::Version.where(number: "1.2.3").count
              }.by(-1)
          end

          it "deletes the child tags" do
            expect{ delete_consumer }.to change{
              PactBroker::Domain::Tag.where(name: "prod").count
              }.by(-1)
          end

          it "deletes the webhooks" do
            expect{ delete_consumer }.to change{
              PactBroker::Webhooks::Webhook.count
              }.by(-1)
          end

          it "deletes the triggered webhooks" do
            expect{ delete_consumer }.to change{
              PactBroker::Webhooks::TriggeredWebhook.count
              }.by(-1)
          end

          it "deletes the webhook executions" do
            expect{ delete_consumer }.to change{
              PactBroker::Webhooks::Execution.count
              }.by(-1)
          end

          it "deletes the child pacts" do
            expect{ delete_consumer }.to change{
              PactBroker::Pacts::PactPublication.count
              }.by(-2)
          end

          it "deletes the verifications" do
            expect{ delete_consumer }.to change{
              PactBroker::Domain::Verification.count
              }.by(-1)
          end
        end

        context "deleting a provider" do
          it "deletes the pacticipant" do
            expect{ delete_provider }.to change{
                PactBroker::Domain::Pacticipant.all.count
              }.by(-1)
          end

          it "does not delete any versions" do
            expect{ delete_provider }.to change{
              PactBroker::Domain::Version.where(number: "1.2.3").count
              }.by(0)
          end

          it "deletes the child tags only if there are any" do
            expect{ delete_provider }.to change{
              PactBroker::Domain::Tag.where(name: "prod").count
              }.by(0)
          end

          it "deletes the webhooks" do
            expect{ delete_provider }.to change{
              PactBroker::Webhooks::Webhook.count
              }.by(-1)
          end

          it "deletes the triggered webhooks" do
            expect{ delete_provider }.to change{
              PactBroker::Webhooks::TriggeredWebhook.count
              }.by(-1)
          end

          it "deletes the webhook executions" do
            expect{ delete_provider }.to change{
              PactBroker::Webhooks::Execution.count
              }.by(-1)
          end

          it "deletes the child pacts" do
            expect{ delete_provider }.to change{
              PactBroker::Pacts::PactPublication.count
              }.by(-2)
          end

          it "deletes the verifications" do
            expect{ delete_provider }.to change{
              PactBroker::Domain::Verification.count
              }.by(-1)
          end

        end
      end
    end
  end
end

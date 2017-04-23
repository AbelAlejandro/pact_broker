require 'pact_broker/domain/version'

module PactBroker

  module Domain

    describe Version do
      describe "#latest_pact_revision" do
        let!(:pact) do
          ProviderStateBuilder.new
            .create_consumer
            .create_provider
            .create_consumer_version
            .create_pact
            .create_pact_revision
            .and_return(:pact)
        end
        let(:version) { Version.order(:id).last }

        it "returns the latest pact revision for the consumer version" do
          expect(version.latest_pact_revision.id).to eq pact.id
        end
      end
    end
  end
end

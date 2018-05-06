require 'pact_broker/api/decorators/verification_decorator'

module PactBroker
  module Api
    module Decorators
      describe VerificationDecorator do

        let(:verification) do
          instance_double('PactBroker::Domain::Verification',
            number: 1,
            success: true,
            provider_version_number: "4.5.6",
            provider_name: 'Provider',
            consumer_name: 'Consumer',
            test_results: { 'arbitrary' => 'json' },
            build_url: 'http://build-url',
            pact_version_sha: '1234',
            pact_version: pact_version,
            execution_date: DateTime.now)
        end

        let(:pact_version) do
          instance_double('PactBroker::Pacts::PactVersion',
            name: 'A name',
            provider_name: 'Provider',
            consumer_name: 'Consumer',
            sha: '1234'
          )
        end

        before do
          allow_any_instance_of(VerificationDecorator).to receive(:pact_version_url).and_return('pact_version_url')
        end

        let(:options) { { user_options: { base_url: 'http://example.org' } } }
        let(:decorator) { VerificationDecorator.new(verification) }

        subject { JSON.parse VerificationDecorator.new(verification).to_json(options), symbolize_names: true }

        it "includes the success status" do
          expect(subject[:success]).to eq true
        end

        it "includes the provider version" do
          expect(subject[:providerApplicationVersion]).to eq "4.5.6"
        end

        it "includes the test results" do
          expect(subject[:testResults]).to eq(arbitrary: 'json')
        end

        it "includes the build URL" do
          expect(subject[:buildUrl]).to eq "http://build-url"
        end

        it "includes a link to itself" do
          expect(subject[:_links][:self][:href]).to match %r{http://example.org/.*/verification-results/1}
        end

        it "includes a link to its pact" do
          expect(subject[:_links][:'pb:pact-version'][:href]).to eq 'pact_version_url'
        end
      end
    end
  end
end

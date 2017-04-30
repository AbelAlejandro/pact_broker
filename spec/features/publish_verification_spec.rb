require 'pact_broker/domain/verification'

describe "Recording a pact verification" do

  let(:path) { "/pacts/provider/Provider/consumer/Consumer/pact-version/#{pact.pact_version_sha}/verifications" }
  let(:verification_content) { load_fixture('verification.json') }
  let(:parsed_response_body) { JSON.parse(subject.body) }

  subject { post path, verification_content, {'CONTENT_TYPE' => 'application/json' }; last_response  }

  let(:pact) do
    ProviderStateBuilder.new
      .create_provider("Provider")
      .create_consumer("Consumer")
      .create_consumer_version("1.2.3")
      .create_pact
      .revise_pact
      .and_return(:pact)
  end

  it "Responds with a 201 Created" do
    expect(subject.status).to be 201
  end

  it "saves a verification against the pact" do
    expect { subject }.to change { PactBroker::Domain::Verification.count }.by(1)
  end

  it "returns a link to itself that can be followed" do
    get_verification_link = parsed_response_body['_links']['self']['href']
    get get_verification_link
    expect(last_response.status).to be 200
    expect(JSON.parse(subject.body)).to include JSON.parse(verification_content)
  end
end

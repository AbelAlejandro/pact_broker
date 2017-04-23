require 'tasks/database'

describe 'migrate to pact versions (migrate 22-24)', no_db_clean: :true do

  def create table_name, params, id_column_name = :id
    database[table_name].insert(params);
    database[table_name].order(id_column_name).last
  end

  def new_connection
    DB.connection_for_env 'test'
  end

  let(:database) { new_connection }

  before do
    PactBroker::Database.delete_database_file
    PactBroker::Database.ensure_database_dir_exists
    database = new_connection
    PactBroker::Database.migrate(22)
  end

  let(:now) { DateTime.new(2017, 1, 1) }
  let(:pact_updated_at) { DateTime.new(2017, 1, 2) }
  let!(:consumer) { create(:pacticipants, {name: 'Consumer', created_at: now, updated_at: now}) }
  let!(:provider) { create(:pacticipants, {name: 'Provider', created_at: now, updated_at: now}) }
  let!(:consumer_version) { create(:versions, {number: '1.2.3', order: 1, pacticipant_id: consumer[:id], created_at: now, updated_at: now}) }
  let!(:pact_version_content) { create(:pact_version_contents, {content: {some: 'json'}.to_json, sha: '1234', created_at: now, updated_at: now}, :sha) }
  let!(:pact_1) { create(:pacts, {version_id: consumer_version[:id], provider_id: provider[:id], pact_version_content_sha: '1234', created_at: now, updated_at: pact_updated_at}) }

  let!(:pact_version_content_orphan) { create(:pact_version_contents, {content: {some: 'json'}.to_json, sha: '4567', created_at: now, updated_at: now}, :sha) }

  let(:do_migration) do
    PactBroker::Database.migrate(34)
    database.schema(:pact_version_contents, reload: true)
  end

  it "deletes orphan pact_version_contents" do
    do_migration
    expect(database[:pact_version_contents].count).to eq 1
  end

  after do
    PactBroker::Database.delete_database_file
    PactBroker::Database.ensure_database_dir_exists
    database = new_connection
    PactBroker::Database.migrate
  end
end

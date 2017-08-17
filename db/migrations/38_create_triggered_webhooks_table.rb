Sequel.migration do
  change do
    create_table(:triggered_webhooks, charset: 'utf8') do
      primary_key :id
      String :trigger, null: false # publication or manual
      String :trigger_uuid, null: false
      foreign_key :pact_publication_id, :pact_publications, null: false
      foreign_key :webhook_id, :webhooks
      String :webhook_uuid, null: false # keep so we can group executions even when webhook is deleted
      foreign_key :consumer_id, :pacticipants, null: false
      foreign_key :provider_id, :pacticipants, null: false
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
      add_index [:pact_publication_id, :webhook_id, :trigger_uuid], unique: true, name: 'uq_triggered_webhook_ppi_wi'
    end
  end
end

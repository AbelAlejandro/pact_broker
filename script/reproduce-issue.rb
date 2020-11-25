#!/usr/bin/env ruby

$LOAD_PATH << "#{Dir.pwd}/lib"

require 'pact_broker/test/http_test_data_builder'

td = PactBroker::Test::HttpTestDataBuilder.new('http://localhost:9292', { })
td.delete_integration(consumer: "MyConsumer", provider: "MyProvider")
  .can_i_deploy(pacticipant: "MyProvider", version: "1", to: "prod")
  .can_i_deploy(pacticipant: "MyConsumer", version: "1", to: "prod")
  .publish_pact(consumer: "MyConsumer", consumer_version: "1", provider: "MyProvider", content_id: "111", tag: "feature/a")
  .can_i_deploy(pacticipant: "MyProvider", version: "1", to: "prod")
  .get_pacts_for_verification(
    enable_pending: true,
    provider_version_tag: "main",
    include_wip_pacts_since: "2020-01-01",
    consumer_version_selectors: [{ tag: "main", latest: true }])
  .print_pacts_for_verification
  .verify_pact(
    index: 0,
    provider_version_tag: "main",
    provider_version: "1",
    success: true
  )
  .print_pacts_for_verification
  .can_i_deploy(pacticipant: "MyProvider", version: "1", to: "prod")
  .can_i_deploy(pacticipant: "MyConsumer", version: "1", to: "prod")
  .deploy_to_prod(pacticipant: "MyProvider", version: "1")
  .can_i_deploy(pacticipant: "MyConsumer", version: "1", to: "prod")
  .deploy_to_prod(pacticipant: "MyConsumer", version: "1")

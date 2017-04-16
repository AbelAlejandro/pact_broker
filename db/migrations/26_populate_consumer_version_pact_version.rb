Sequel.migration do
  up do
    run("insert into consumer_versions_pact_contents
        (id, consumer_version_id, provider_id, revision_number, pact_version_id, created_at)
      select ap.id, ap.consumer_version_id, ap.provider_id, 1, pc.id, ap.updated_at
      from all_pacts ap inner join pact_contents pc
      on pc.sha = ap.pact_version_content_sha")
  end

  down do
    run("delete from consumer_versions_pact_contents")
  end
end

Sequel.migration do
  change do
    create_table(:branches, charset: "utf8") do
      primary_key :id
      String :name
      foreign_key :pacticipant_id, :pacticipants, null: false, on_delete: :cascade
      Integer :latest_branch_version_id
      Integer :latest_version_id
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
      index [:name, :pacticipant_id], unique: true, name: :branches_name_pacticipant_id_index
    end

    create_table(:branch_versions, charset: "utf8") do
      primary_key :id
      foreign_key :branch_id, :branches, null: false, foreign_key_constraint_name: :branch_versions_branches_fk, on_delete: :cascade
      foreign_key :version_id, :versions, null: false, foreign_key_constraint_name: :branch_versions_versions_fk, on_delete: :cascade
      Integer :version_order, null: false
      Integer :pacticipant_id, null: false
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
      index [:branch_id, :version_id], unique: true, name: :branch_versions_branch_id_version_id_index
      index [:pacticipant_id, :branch_id, :version_order], name: :branch_versions_pacticipant_id_branch_id_version_order_index
    end

    create_table(:branch_heads) do
      primary_key :id
      foreign_key :branch_id, :branches, null: false, on_delete: :cascade
      foreign_key :branch_version_id, :branch_versions, null: false, on_delete: :cascade
      Integer :version_id, null: false
      Integer :pacticipant_id, null: false
      index([:branch_id], unique: true, name: :branch_heads_branch_id_index)
    end
  end
end

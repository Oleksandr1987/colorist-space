class AddUniqueNameIndexToClients < ActiveRecord::Migration[8.1]
  def change
    add_index :clients,
      "user_id, LOWER(TRIM(first_name)), LOWER(TRIM(COALESCE(last_name, '')))",
      unique: true,
      name: "index_clients_on_unique_name"
  end
end

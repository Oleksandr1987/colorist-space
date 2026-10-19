class AddNormalizedNameToClients < ActiveRecord::Migration[8.1]
  class MigrationClient < ActiveRecord::Base
    self.table_name = "clients"
  end

  def up
    add_column :clients, :normalized_name, :string

    MigrationClient.reset_column_information

    MigrationClient.find_each do |client|
      normalized_name = [client.first_name, client.last_name]
        .join(" ")
        .downcase
        .split
        .sort
        .join(" ")

      client.update_columns(normalized_name: normalized_name)
    end

    change_column_null :clients, :normalized_name, false

    add_index :clients, [:user_id, :normalized_name],
      unique: true,
      name: "index_clients_on_user_id_and_normalized_name"
  end

  def down
    remove_index :clients, name: "index_clients_on_user_id_and_normalized_name"
    remove_column :clients, :normalized_name
  end
end

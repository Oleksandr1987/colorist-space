class AddUniqueIndexToClientsPhone < ActiveRecord::Migration[8.1]
  def change
    add_index :clients, [:user_id, :phone], unique: true, name: "index_clients_on_user_id_and_phone"
  end
end

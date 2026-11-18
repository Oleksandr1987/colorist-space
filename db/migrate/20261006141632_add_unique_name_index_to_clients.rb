class AddUniqueNameIndexToClients < ActiveRecord::Migration[8.1]
  def change
    # Uniqueness is enforced by
    # index_clients_on_user_id_and_normalized_name.
  end
end

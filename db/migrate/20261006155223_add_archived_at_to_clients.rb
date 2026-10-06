class AddArchivedAtToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :archived_at, :datetime
    add_index :clients, :archived_at
  end
end

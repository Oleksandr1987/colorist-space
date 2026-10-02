class AddArchivedAtToCareProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :care_products, :archived_at, :datetime
    add_index :care_products, :archived_at
  end
end

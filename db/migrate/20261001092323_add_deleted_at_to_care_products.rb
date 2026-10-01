class AddDeletedAtToCareProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :care_products, :deleted_at, :datetime
    add_index :care_products, :deleted_at
  end
end

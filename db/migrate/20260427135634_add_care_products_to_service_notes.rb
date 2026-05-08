class AddCareProductsToServiceNotes < ActiveRecord::Migration[8.1]
  def change
    add_column :service_notes, :care_products, :json, default: []
  end
end

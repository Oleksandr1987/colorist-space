class AddStockAfterToCareProductStockMovements < ActiveRecord::Migration[8.1]
  def change
    add_column :care_product_stock_movements, :stock_after, :integer
  end
end


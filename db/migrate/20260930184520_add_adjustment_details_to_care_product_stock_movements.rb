class AddAdjustmentDetailsToCareProductStockMovements < ActiveRecord::Migration[8.1]
  def change
    add_column :care_product_stock_movements, :adjustment_reason, :string
    add_column :care_product_stock_movements, :note, :text
  end
end

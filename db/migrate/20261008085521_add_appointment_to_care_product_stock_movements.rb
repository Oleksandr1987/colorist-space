class AddAppointmentToCareProductStockMovements < ActiveRecord::Migration[8.1]
  def change
    add_reference :care_product_stock_movements, :appointment, null: true, foreign_key: true
  end
end

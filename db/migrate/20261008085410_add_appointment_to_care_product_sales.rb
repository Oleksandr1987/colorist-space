class AddAppointmentToCareProductSales < ActiveRecord::Migration[8.1]
  def change
    add_reference :care_product_sales, :appointment, null: true, foreign_key: true
  end
end

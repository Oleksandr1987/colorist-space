# frozen_string_literal: true

class CreateCareProductSales < ActiveRecord::Migration[8.1]
  def change
    create_table :care_product_sales do |t|
      t.references :user, null: false, foreign_key: true
      t.references :care_product, null: false, foreign_key: true
      t.references :service_note, null: true, foreign_key: true
      t.references :stock_movement, null: true, foreign_key: { to_table: :care_product_stock_movements }

      t.integer :quantity, null: false
      t.decimal :unit_price, precision: 10, scale: 2, null: false
      t.decimal :unit_cost, precision: 10, scale: 2, null: false
      t.date :sold_on, null: false

      t.timestamps
    end

    add_index :care_product_sales, :sold_on
  end
end

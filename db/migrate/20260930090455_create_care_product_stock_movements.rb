class CreateCareProductStockMovements < ActiveRecord::Migration[8.1]
  def change
    create_table :care_product_stock_movements do |t|
      t.references :user, null: false, foreign_key: true
      t.references :care_product, null: false, foreign_key: true
      t.references :service_note, null: true, foreign_key: true
      t.references :expense, null: true, foreign_key: true

      t.string :movement_type, null: false
      t.integer :quantity, null: false
      t.decimal :unit_cost, precision: 10, scale: 2
      t.date :occurred_on, null: false

      t.timestamps
    end

    add_index :care_product_stock_movements, :movement_type
    add_index :care_product_stock_movements, :occurred_on
  end
end

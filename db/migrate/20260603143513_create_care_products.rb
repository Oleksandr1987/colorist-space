class CreateCareProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :care_products do |t|
      t.references :user, null: false, foreign_key: true
      t.string :brand
      t.string :name
      t.string :category
      t.integer :purchase_price
      t.integer :sale_price
      t.integer :stock_quantity

      t.timestamps
    end
  end
end

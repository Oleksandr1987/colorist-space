class CreateFormulaProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :formula_products do |t|
      t.references :user, null: false, foreign_key: true
      t.string :category
      t.string :brand
      t.string :name
      t.string :unit
      t.integer :price_per_unit

      t.timestamps
    end
  end
end

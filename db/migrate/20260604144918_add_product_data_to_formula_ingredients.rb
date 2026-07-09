class AddProductDataToFormulaIngredients < ActiveRecord::Migration[8.1]
  def change
    add_column :formula_ingredients, :formula_product_id, :integer
    add_column :formula_ingredients, :price, :decimal, precision: 10, scale: 2, default: 0

    add_index :formula_ingredients, :formula_product_id
  end
end


class AddKindToFormulaIngredients < ActiveRecord::Migration[8.1]
  def change
    add_column :formula_ingredients, :kind, :string, default: "color", null: false
    add_index :formula_ingredients, :kind
  end
end

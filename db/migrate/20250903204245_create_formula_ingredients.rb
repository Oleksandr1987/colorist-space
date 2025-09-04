class CreateFormulaIngredients < ActiveRecord::Migration[8.0]
  def change
    create_table :formula_ingredients do |t|
      t.references :formula_step, null: false, foreign_key: true
      t.string :shade, null: false
      t.string :brand
      t.string :amount, null: false
      t.timestamps
    end
  end
end

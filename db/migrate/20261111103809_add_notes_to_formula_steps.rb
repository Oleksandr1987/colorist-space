class AddNotesToFormulaSteps < ActiveRecord::Migration[8.1]
  def change
    add_column :formula_steps, :notes, :text
  end
end

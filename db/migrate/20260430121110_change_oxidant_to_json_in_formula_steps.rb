class ChangeOxidantToJsonInFormulaSteps < ActiveRecord::Migration[8.1]
  def change
    change_column :formula_steps, :oxidant, :json
  end
end

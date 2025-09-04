class CreateFormulaSteps < ActiveRecord::Migration[8.0]
  def change
    create_table :formula_steps do |t|
      t.references :service_note, null: false, foreign_key: true
      t.string :section, null: false
      t.string :oxidant
      t.string :time
      t.timestamps
    end
  end
end

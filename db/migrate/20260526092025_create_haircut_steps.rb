class CreateHaircutSteps < ActiveRecord::Migration[8.1]
  def change
    create_table :haircut_steps do |t|
      t.references :service_note, null: false, foreign_key: true
      t.string :zone
      t.string :instrument
      t.string :parting
      t.string :elevation
      t.string :cut_type
      t.text :notes

      t.timestamps
    end
  end
end

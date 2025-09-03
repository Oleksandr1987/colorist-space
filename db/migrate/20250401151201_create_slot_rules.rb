class CreateSlotRules < ActiveRecord::Migration[8.0]
  def change
    create_table :slot_rules do |t|
      t.references :user, null: false, foreign_key: true
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.string :weekdays, null: false
      t.text :rule, null: false

      t.timestamps
    end
  end
end

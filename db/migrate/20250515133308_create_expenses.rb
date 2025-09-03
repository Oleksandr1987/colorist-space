class CreateExpenses < ActiveRecord::Migration[8.0]
  def change
    create_table :expenses do |t|
      t.string :category, null: false
      t.string :note
      t.integer :amount, null: false
      t.date :spent_on, null: false
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end

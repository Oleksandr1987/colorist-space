class CreateClientPhones < ActiveRecord::Migration[8.1]
  def change
    create_table :client_phones do |t|
      t.references :client, null: false, foreign_key: true
      t.string :phone, null: false

      t.timestamps
    end

    add_index :client_phones, [:phone], unique: true
  end
end

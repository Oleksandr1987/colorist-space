class CreateClients < ActiveRecord::Migration[8.0]
  def change
    create_table :clients do |t|
      t.references :user, null: false, foreign_key: true
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :phone, null: false
      t.date   :birthdate
      t.string :hair_type
      t.string :hair_length
      t.string :hair_structure
      t.string :hair_density
      t.string :scalp_condition
      t.text   :note

      t.timestamps
    end
  end
end

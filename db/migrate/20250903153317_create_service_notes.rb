# db/migrate/20250903153000_create_service_notes.rb
class CreateServiceNotes < ActiveRecord::Migration[8.0]
  def change
    create_table :service_notes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :client, null: false, foreign_key: true
      t.references :appointment, null: true, foreign_key: true

      t.string :service_type, null: false
      t.json :data, null: false, default: {}
      t.text :notes
      t.integer :price, null: true

      t.timestamps
    end

    add_index :service_notes, [:client_id, :created_at]
  end
end


class CreateServiceNoteServices < ActiveRecord::Migration[8.1]
  def change
    create_table :service_note_services do |t|
      t.references :service_note, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true

      t.timestamps
    end

    add_index :service_note_services, [:service_note_id, :service_id], unique: true
  end
end

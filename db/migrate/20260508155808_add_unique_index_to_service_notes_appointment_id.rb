class AddUniqueIndexToServiceNotesAppointmentId < ActiveRecord::Migration[8.1]
  def change
    remove_index :service_notes, :appointment_id,
      if_exists: true

    add_index :service_notes,
              :appointment_id,
              unique: true,
              name: "index_service_notes_on_appointment_id_unique"
  end
end

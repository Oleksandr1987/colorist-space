# frozen_string_literal: true

class AddUniqueIndexToServiceNotesAppointmentId < ActiveRecord::Migration[8.1]
  def up
    add_index :service_notes,
      :appointment_id,
      unique: true,
      name: "index_service_notes_on_appointment_id_unique"

    remove_index :service_notes,
      name: "index_service_notes_on_appointment_id",
      if_exists: true
  end

  def down
    add_index :service_notes,
      :appointment_id,
      name: "index_service_notes_on_appointment_id"

    remove_index :service_notes,
      name: "index_service_notes_on_appointment_id_unique"
  end
end

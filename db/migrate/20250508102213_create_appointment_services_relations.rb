class CreateAppointmentServicesRelations < ActiveRecord::Migration[8.0]
  def change
    create_table :appointment_services_relations do |t|
      t.references :appointment, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true

      t.timestamps
    end

    add_index :appointment_services_relations, [:appointment_id, :service_id], unique: true, name: "appt_serv_in"
  end
end

class AddSnapshotsToAppointmentServicesRelations < ActiveRecord::Migration[8.1]
  def change
    add_column :appointment_services_relations, :service_name, :string, null: false
    add_column :appointment_services_relations, :service_category, :string, null: false

    add_index :appointment_services_relations, :service_category
  end
end

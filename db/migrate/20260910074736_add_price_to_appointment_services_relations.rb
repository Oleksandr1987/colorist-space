class AddPriceToAppointmentServicesRelations < ActiveRecord::Migration[8.1]
  def change
    add_column :appointment_services_relations,
               :price,
               :integer,
               null: false
  end
end

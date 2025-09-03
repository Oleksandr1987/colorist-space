class AddServiceTypeAndUnitToServices < ActiveRecord::Migration[8.0]
  def change
    add_column :services, :service_type, :string, null: false, default: "service"
    add_column :services, :unit, :string
  end
end

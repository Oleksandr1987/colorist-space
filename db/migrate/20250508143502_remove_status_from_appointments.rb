class RemoveStatusFromAppointments < ActiveRecord::Migration[8.0]
  def change
    remove_column :appointments, :status, :string
  end
end

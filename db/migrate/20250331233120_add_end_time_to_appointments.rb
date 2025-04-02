class AddEndTimeToAppointments < ActiveRecord::Migration[8.0]
  def change
    add_column :appointments, :end_time, :time
  end
end

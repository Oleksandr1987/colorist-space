class RemoveBirthdateAndMakeLastNameOptionalFromClients < ActiveRecord::Migration[8.0]
  def change
    remove_column :clients, :birthdate, :date
    change_column_null :clients, :last_name, true
  end
end

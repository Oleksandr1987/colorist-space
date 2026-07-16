class AddBirthdayToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :birthday, :string
  end
end

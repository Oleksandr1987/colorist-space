class AddAccessControlColumnsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :subscription_expires_at, :date
    add_column :users, :plan_name, :string
    add_column :users, :role, :string
  end
end

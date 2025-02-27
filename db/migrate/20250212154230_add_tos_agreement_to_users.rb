class AddTosAgreementToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :tos_agreement, :boolean
  end
end

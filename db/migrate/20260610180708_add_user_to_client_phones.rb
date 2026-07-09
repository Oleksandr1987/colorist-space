class AddUserToClientPhones < ActiveRecord::Migration[8.1]
  def change
    add_reference :client_phones, :user, foreign_key: true
  end
end

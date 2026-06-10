class ChangeClientPhonesPhoneIndex < ActiveRecord::Migration[8.1]
  def change
    remove_index :client_phones, :phone

    add_index :client_phones,
              [:user_id, :phone],
              unique: true
  end
end

class AddWayforpayIntegrationState < ActiveRecord::Migration[8.1]
  def change
    add_column :subscriptions, :renewal_amount_minor, :integer
    add_column :subscriptions, :next_amount_minor, :integer
    add_column :subscriptions, :provider_status, :string
    add_column :subscriptions, :last_provider_paid_at, :datetime
    add_column :subscriptions, :last_synced_at, :datetime
    add_column :subscriptions, :checkout_payment_id, :bigint
    add_column :subscriptions, :management_intent, :json
    add_column :subscription_payments, :source, :string, null: false, default: "purchase"
    add_column :subscription_payments, :checkout_expires_at, :datetime
    add_column :subscription_payments, :checkout_data, :json
    create_table :wayforpay_events do |t|
      t.string :fingerprint, null: false
      t.string :merchant_account, null: false
      t.string :order_reference, null: false
      t.json :metadata, null: false
      t.string :state, null: false, default: "received"
      t.timestamps
    end

    add_index :wayforpay_events, :fingerprint, unique: true
    add_index :wayforpay_events, [:state, :created_at]
  end
end

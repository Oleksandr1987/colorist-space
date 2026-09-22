# frozen_string_literal: true

class CreateSubscriptionsAndSubscriptionPayments < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :source, null: false, default: "wayforpay"
      t.string :plan, null: false, default: "none"
      t.string :status, null: false, default: "pending"
      t.datetime :trial_ends_at
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.boolean :auto_renew, null: false, default: false
      t.string :merchant_account
      t.string :wayforpay_order_reference
      t.datetime :cancelled_at
      t.string :next_plan
      t.datetime :next_plan_starts_at
      t.timestamps
    end

    add_index :subscriptions, [:merchant_account, :wayforpay_order_reference],
      unique: true, name: "index_subscriptions_on_merchant_and_reference"
    add_check_constraint :subscriptions,
      "current_period_start IS NULL OR current_period_end IS NULL OR current_period_end > current_period_start",
      name: "subscription_period_is_ordered"

    create_table :subscription_payments do |t|
      t.references :subscription, null: false, foreign_key: true
      t.string :merchant_account, null: false
      t.string :order_reference, null: false
      t.string :plan, null: false
      t.integer :amount_minor, null: false
      t.string :currency, null: false, default: "UAH"
      t.string :status, null: false, default: "pending"
      t.string :provider_status
      t.string :reason_code
      t.datetime :paid_at
      t.datetime :processed_at
      t.datetime :period_start
      t.datetime :period_end
      # Store only explicitly allowed metadata; never store recToken or secrets here.
      t.json :callback_metadata
      t.timestamps
    end

    add_index :subscription_payments, [:merchant_account, :order_reference],
      unique: true, name: "index_subscription_payments_on_merchant_and_reference"
    add_check_constraint :subscription_payments, "amount_minor > 0",
      name: "subscription_payment_amount_is_positive"
    add_check_constraint :subscription_payments,
      "period_start IS NULL OR period_end IS NULL OR period_end > period_start",
      name: "subscription_payment_period_is_ordered"
  end
end

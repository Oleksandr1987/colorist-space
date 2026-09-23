class RemoveLegacySubscriptionFields < ActiveRecord::Migration[8.1]
  def up
    # Use migration-local models, independent of current application validations.
    subscriptions = Class.new(ActiveRecord::Base) { self.table_name = "subscriptions" }
    old_rows = subscriptions.where(source: "legacy").or(subscriptions.where(plan: "legacy"))
    if old_rows.where("current_period_end > ?", Time.current).exists?
      raise ActiveRecord::MigrationError, "Active legacy access still exists; do not remove it without a migration plan"
    end
    # Expired/trial records may remain from running the old import in development.
    # No period, trial deadline, payment, or provider reference is removed here.
    old_rows.where(plan: "legacy").update_all(plan: "none")
    subscriptions.where(source: "legacy").update_all(source: "wayforpay")
    remove_column :users, :plan_name, :string
    remove_column :users, :subscription_expires_at, :date
  end

  def down
    # Recreates columns only; previously removed values cannot be reconstructed.
    add_column :users, :plan_name, :string
    add_column :users, :subscription_expires_at, :date
  end
end

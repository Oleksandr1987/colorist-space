module SubscriptionAccess
  extend ActiveSupport::Concern

  included do
    has_one :subscription, dependent: :restrict_with_error
    after_create :initialize_subscription
  end

  def has_active_subscription?
    subscription&.paid_access? || false
  end

  def subscription_will_expire_soon?
    subscription&.expires_soon? || false
  end

  def on_trial?
    subscription&.on_trial? || false
  end

  def trial_days_left
    subscription&.trial_days_left || 0
  end

  def has_write_access?
    superadmin? || has_active_subscription? || on_trial?
  end

  def subscription_plan
    superadmin? ? "superadmin" : (subscription&.plan || "none")
  end

  private

  def initialize_subscription
    create_subscription!(source: "wayforpay", plan: "trial", status: "trialing",
      trial_ends_at: created_at + 7.days)
  end
end

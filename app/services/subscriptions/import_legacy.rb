# frozen_string_literal: true

module Subscriptions
  # Re-runnable while User's old columns are still authoritative.
  # A migrated WayForPay record must have source="wayforpay" and is never overwritten.
  class ImportLegacy
    class UnsupportedPlan < StandardError; end

    def self.call
      counts = { imported: 0, skipped: 0 }
      User.find_each do |user|
        result = new(user).call
        counts[result] += 1
      end
      counts
    end

    def initialize(user)
      @user = user
    end

    def call
      @user.with_lock do
        subscription = Subscription.find_by(user_id: @user.id)
        return :skipped if subscription && subscription.source != "legacy"

        subscription ||= Subscription.new(user: @user)
        subscription.assign_attributes(attributes)
        subscription.save!

        :imported
      end
    end

    private

    def attributes
      # Read columns directly: future User compatibility methods may delegate elsewhere.
      old_plan = @user[:plan_name]
      old_expiry = @user[:subscription_expires_at]
      now = Time.current

      base = {
        source: "legacy", auto_renew: false, merchant_account: nil,
        wayforpay_order_reference: nil, cancelled_at: nil,
        next_plan: nil, next_plan_starts_at: nil,
        current_period_start: nil, current_period_end: nil, trial_ends_at: nil
      }

      if old_expiry.present?
        # Old User access includes the entire expiration day. Start of the following
        # day keeps that contract when converting a date to an exclusive timestamp.
        ends_at = (old_expiry + 1.day).in_time_zone.beginning_of_day
        plan = old_plan.in?(Subscription::PAID_PLANS) ? old_plan : "legacy"
        base.merge(plan: plan, current_period_end: ends_at,
          status: ends_at > now ? "active" : "expired")
      elsif old_plan == "trial"
        ends_at = @user.created_at + 7.days
        base.merge(plan: "trial", trial_ends_at: ends_at,
          status: ends_at > now ? "trialing" : "expired")
      elsif old_plan.blank? || old_plan.in?(Subscription::PAID_PLANS) || old_plan == "superadmin"
        # A role is not a purchasable plan. Superadmin access remains User#superadmin?.
        base.merge(plan: old_plan.in?(Subscription::PAID_PLANS) ? old_plan : "none",
          status: old_plan.in?(Subscription::PAID_PLANS) ? "expired" : "pending")
      else
        raise UnsupportedPlan, "Unsupported legacy plan for User #{@user.id}; inspect before migration"
      end
    end
  end
end

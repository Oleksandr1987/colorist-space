
# frozen_string_literal: true

require "rails_helper"

RSpec.describe SubscriptionAccess do
  describe "#has_active_subscription?" do
    it "returns false without a subscription" do
      user = build(:user)

      expect(user.has_active_subscription?).to be(false)
    end

    it "returns false during trial" do
      user = create(:user, :trial)

      expect(user.has_active_subscription?).to be(false)
    end

    it "returns true for active paid access" do
      user = create(:user, :trial)

      user.subscription.update!(plan: "monthly", status: "active", current_period_end: 1.month.from_now)

      expect(user.has_active_subscription?).to be(true)
    end
  end

  describe "#subscription_will_expire_soon?" do
    it "returns false without a subscription" do
      user = build(:user)

      expect(user.subscription_will_expire_soon?).to be(false)
    end

    it "returns true when subscription expires soon" do
      user = create(:user, :trial)

      user.subscription.update!(plan: "monthly", status: "active", current_period_end: 2.days.from_now)

      expect(user.subscription_will_expire_soon?).to be(true)
    end
  end

  describe "#on_trial?" do
    it "returns false without a subscription" do
      user = build(:user)

      expect(user.on_trial?).to be(false)
    end

    it "returns true during an active trial" do
      user = create(:user, :trial)

      expect(user.on_trial?).to be(true)
    end
  end

  describe "#trial_days_left" do
    it "returns zero without a subscription" do
      user = build(:user)

      expect(user.trial_days_left).to eq(0)
    end

    it "returns remaining trial days" do
      user = create(:user, :trial)

      expect(user.trial_days_left).to be_positive
    end
  end

  describe "#has_write_access?" do
    it "allows superadmin access" do
      user = create(:user, :superadmin)

      expect(user.has_write_access?).to be(true)
    end

    it "allows active paid subscribers" do
      user = create(:user, :trial)

      user.subscription.update!(plan: "monthly", status: "active", current_period_end: 1.month.from_now)

      expect(user.has_write_access?).to be(true)
    end

    it "allows users on trial" do
      user = create(:user, :trial)

      expect(user.has_write_access?).to be(true)
    end

    it "denies access when trial has expired" do
      user = create(:user, :trial)

      user.subscription.update!(status: "expired", trial_ends_at: 1.day.ago)

      expect(user.has_write_access?).to be(false)
    end
  end

  describe "#subscription_plan" do
    it "returns superadmin for superadmins" do
      user = create(:user, :superadmin)

      expect(user.subscription_plan).to eq("superadmin")
    end

    it "returns none without a subscription" do
      user = build(:user)

      expect(user.subscription_plan).to eq("none")
    end

    it "returns the current subscription plan" do
      user = create(:user, :trial)

      expect(user.subscription_plan).to eq("trial")
    end
  end

  describe "subscription initialization" do
    it "creates a trial subscription after user creation" do
      user = create(:user)

      expect(user.subscription).to be_present
      expect(user.subscription.source).to eq("wayforpay")
      expect(user.subscription.plan).to eq("trial")
      expect(user.subscription.status).to eq("trialing")
      expect(user.subscription.trial_ends_at).to be_within(1.second).of(
        user.created_at + 168.hours
      )
    end
  end
end

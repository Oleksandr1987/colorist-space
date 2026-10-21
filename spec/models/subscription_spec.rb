# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscription do
  include ActiveSupport::Testing::TimeHelpers

  let(:now) { Time.zone.local(2026, 10, 21, 14, 5) }

  before { travel_to(now) }
  after { travel_back }

  def build_subscription(**attributes)
    described_class.new({ plan: "monthly", status: "active", source: "wayforpay",
      auto_renew: false, current_period_start: now, current_period_end: now + 30.days
    }.merge(attributes))
  end

  def build_trial(**attributes)
    build_subscription(plan: "trial", status: "trialing",
      current_period_start: nil, current_period_end: nil, trial_ends_at: now + 168.hours, **attributes
    )
  end

  describe "associations" do
    it { is_expected.to belong_to(:user) }

    it { is_expected.to have_many(:subscription_payments).dependent(:restrict_with_error) }
  end

  describe "validations" do
    subject(:subscription) { build_subscription }

    let(:user) { create(:user) }

    before do
      user.subscription.destroy!
      subscription.user = user
    end

    it "is valid with valid attributes" do
      expect(subscription).to be_valid
    end

    it "requires a valid source" do
      subscription.source = "unknown"

      expect(subscription).not_to be_valid
      expect(subscription.errors.of_kind?(:source, :inclusion)).to be(true)
    end

    it "requires a valid plan" do
      subscription.plan = "weekly"

      expect(subscription).not_to be_valid
      expect(subscription.errors.of_kind?(:plan, :inclusion)).to be(true)
    end

    it "requires a valid status" do
      subscription.status = "unknown"

      expect(subscription).not_to be_valid
      expect(subscription.errors.of_kind?(:status, :inclusion)).to be(true)
    end

    it "requires auto_renew to be boolean" do
      subscription.auto_renew = nil

      expect(subscription).not_to be_valid
      expect(subscription.errors.of_kind?(:auto_renew, :inclusion)).to be(true)
    end

    context "when automatic renewal is enabled" do
      before { subscription.auto_renew = true }

      it "requires provider identity" do
        expect(subscription).not_to be_valid
        expect(subscription.errors[:merchant_account]).to be_present
        expect(subscription.errors[:wayforpay_order_reference]).to be_present
      end

      it "allows automatic renewal for a paid plan" do
        subscription.assign_attributes(merchant_account: "merchant", wayforpay_order_reference: "order-123")

        expect(subscription).to be_valid
      end

      it "rejects automatic renewal for a trial" do
        subscription.assign_attributes(plan: "trial", merchant_account: "merchant", wayforpay_order_reference: "order-123")

        expect(subscription).not_to be_valid
        expect(subscription.errors.of_kind?(:auto_renew, :invalid)).to be(true)
      end

      it "rejects automatic renewal after cancellation" do
        subscription.assign_attributes(cancelled_at: now, merchant_account: "merchant", wayforpay_order_reference: "order-123")

        expect(subscription).not_to be_valid
        expect(subscription.errors.of_kind?(:auto_renew, :invalid)).to be(true)
      end
    end

    context "when validating subscription periods" do
      it "accepts a correctly ordered period" do
        expect(subscription).to be_valid
      end

      it "rejects equal start and end times" do
        subscription.current_period_end = now

        expect(subscription).not_to be_valid
      end

      it "rejects an end before the start" do
        subscription.current_period_end = now - 1.second

        expect(subscription).not_to be_valid
      end

      it "allows a missing period start" do
        subscription.current_period_start = nil

        expect(subscription).to be_valid
      end
    end

    context "when scheduling the next plan" do
      it "accepts a complete scheduled plan" do
        subscription.assign_attributes(next_plan: "yearly", next_plan_starts_at: now + 30.days)

        expect(subscription).to be_valid
        expect(subscription.plan).to eq("monthly")
      end

      it "requires a start date when next_plan is present" do
        subscription.next_plan = "yearly"

        expect(subscription).not_to be_valid
        expect(subscription.errors[:next_plan_starts_at]).to be_present
      end

      it "requires next_plan when a start date is present" do
        subscription.next_plan_starts_at = now + 30.days

        expect(subscription).not_to be_valid
        expect(subscription.errors[:next_plan]).to be_present
      end

      it "rejects an unsupported next plan" do
        subscription.assign_attributes(next_plan: "trial", next_plan_starts_at: now + 30.days)

        expect(subscription).not_to be_valid
        expect(subscription.errors.of_kind?(:next_plan, :inclusion)).to be(true)
      end
    end

    it "enforces one subscription per user at the model level" do
      subscription.save!

      duplicate = build_subscription(user: user)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors.of_kind?(:user_id, :taken)).to be(true)
    end

    it "enforces one subscription per user at the database level" do
      subscription.save!

      expect do
        described_class.transaction(requires_new: true) do
          described_class.insert_all!([ {
            user_id: user.id, plan: "none", status: "pending", source: "wayforpay", auto_renew: false, created_at: now, updated_at: now
          } ])
        end
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "#paid_access?" do
    subject(:subscription) { build_subscription }

    it "grants access during an active paid period" do
      expect(subscription.paid_access?).to be(true)
    end

    it "grants access exactly at period start" do
      expect(subscription.paid_access?(at: now)).to be(true)
    end

    it "does not grant access before period start" do
      expect(subscription.paid_access?(at: now - 1.second)).to be(false)
    end

    it "grants access one second before period end" do
      expect(subscription.paid_access?(at: subscription.current_period_end - 1.second)).to be(true)
    end

    it "ends access exactly at the exclusive period end" do
      expect(subscription.paid_access?(at: subscription.current_period_end)).to be(false)
    end

    it "does not grant access after expiration" do
      expect(subscription.paid_access?(at: subscription.current_period_end + 1.second)).to be(false)
    end

    it "preserves purchased access after cancellation" do
      subscription.assign_attributes(status: "cancelled", cancelled_at: now, auto_renew: false)

      expect(subscription.paid_access?).to be(true)
    end

    it "does not grant access from active status alone" do
      subscription.current_period_end = nil

      expect(subscription.paid_access?).to be(false)
    end

    it "does not grant paid access for a trial plan" do
      subscription.plan = "trial"

      expect(subscription.paid_access?).to be(false)
    end

    it "supports a yearly paid plan" do
      subscription.plan = "yearly"

      expect(subscription.paid_access?).to be(true)
    end

    it "allows a missing period start" do
      subscription.current_period_start = nil

      expect(subscription.paid_access?).to be(true)
    end
  end

  describe "#on_trial?" do
    subject(:subscription) { build_trial }

    it "returns true during trial" do
      expect(subscription.on_trial?).to be(true)
    end

    it "returns true one second before expiration" do
      expect(subscription.on_trial?(at: subscription.trial_ends_at - 1.second)).to be(true)
    end

    it "returns false exactly at expiration" do
      expect(subscription.on_trial?(at: subscription.trial_ends_at)).to be(false)
    end

    it "returns false after expiration" do
      expect(subscription.on_trial?(at: subscription.trial_ends_at + 1.second)).to be(false)
    end

    it "returns false without trial_ends_at" do
      subscription.trial_ends_at = nil

      expect(subscription.on_trial?).to be(false)
    end

    it "returns false for a paid plan" do
      subscription.plan = "monthly"

      expect(subscription.on_trial?).to be(false)
    end
  end

  describe "#trial_days_left" do
    subject(:subscription) { build_trial }

    it "returns 7 days at the beginning of trial" do
      expect(subscription.trial_days_left).to eq(7)
    end

    it "returns 6 days after exactly 24 hours" do
      expect(subscription.trial_days_left(at: now + 24.hours)).to eq(6)
    end

    it "returns 5 days after exactly 48 hours" do
      expect(subscription.trial_days_left(at: now + 48.hours)).to eq(5)
    end

    it "rounds remaining partial days up" do
      expect(subscription.trial_days_left(at: now + 25.hours)).to eq(6)
    end

    it "returns 1 during the last hour" do
      expect(subscription.trial_days_left(at: now + 167.hours)).to eq(1)
    end

    it "returns 0 exactly at expiration" do
      expect(subscription.trial_days_left(at: now + 168.hours)).to eq(0)
    end

    it "returns 0 after expiration" do
      expect(subscription.trial_days_left(at: now + 200.hours)).to eq(0)
    end

    it "returns 0 without trial_ends_at" do
      subscription.trial_ends_at = nil

      expect(subscription.trial_days_left).to eq(0)
    end

    context "when during daylight saving time transition" do
      let(:now) { Time.zone.local(2026, 10, 21, 14, 5) }

      it "calculates remaining days using 24-hour periods" do
        expect(subscription.trial_ends_at - now).to eq(168.hours)
        expect(subscription.trial_days_left(at: now + 48.hours)).to eq(5)
      end

      it "does not add an extra day when winter time begins" do
        expect(subscription.trial_days_left(at: now + 120.hours)).to eq(2)
      end
    end
  end

  describe "#write_access?" do
    it "grants access with an active paid subscription" do
      expect(build_subscription.write_access?).to be(true)
    end

    it "grants access during trial" do
      expect(build_trial.write_access?).to be(true)
    end

    it "denies access after paid subscription expiration" do
      subscription = build_subscription(current_period_end: now)

      expect(subscription.write_access?).to be(false)
    end

    it "denies access after trial expiration" do
      subscription = build_trial(trial_ends_at: now)

      expect(subscription.write_access?).to be(false)
    end

    it "denies access without a valid plan" do
      subscription = build_subscription(plan: "none", status: "pending")

      expect(subscription.write_access?).to be(false)
    end
  end

  describe "#expires_soon?" do
    it "returns true when expiration is within 3 days" do
      subscription = build_subscription(current_period_end: now + 2.days)

      expect(subscription.expires_soon?).to be(true)
    end

    it "returns true exactly 3 days before expiration" do
      subscription = build_subscription(current_period_end: now + 72.hours)

      expect(subscription.expires_soon?).to be(true)
    end

    it "returns false when expiration is more than 3 days away" do
      subscription = build_subscription(current_period_end: now + 4.days)

      expect(subscription.expires_soon?).to be(false)
    end

    it "returns false for an expired subscription" do
      subscription = build_subscription(current_period_end: now)

      expect(subscription.expires_soon?).to be(false)
    end

    it "returns false for a trial" do
      expect(build_trial.expires_soon?).to be(false)
    end
  end

  describe "#display_status" do
    it "returns trialing for an active trial" do
      expect(build_trial.display_status).to eq("trialing")
    end

    it "returns active for a paid subscription" do
      expect(build_subscription.display_status).to eq("active")
    end

    it "returns cancelled when paid access remains after cancellation" do
      subscription = build_subscription(status: "cancelled", cancelled_at: now)

      expect(subscription.display_status).to eq("cancelled")
    end

    it "returns expired when paid period ends" do
      subscription = build_subscription(current_period_end: now)

      expect(subscription.display_status).to eq("expired")
    end

    it "returns expired when trial ends" do
      subscription = build_trial(trial_ends_at: now)

      expect(subscription.display_status).to eq("expired")
    end

    it "returns stored status when no access period exists" do
      subscription = build_subscription(plan: "none", status: "pending", current_period_start: nil, current_period_end: nil)

      expect(subscription.display_status).to eq("pending")
    end
  end
end


# frozen_string_literal: true

require "rails_helper"

RSpec.describe SubscriptionAccess do
  include ActiveSupport::Testing::TimeHelpers

  let(:now) { Time.zone.local(2026, 10, 21, 14, 5) }
  let(:user) { build(:user) }

  describe "subscription initialization" do
    before { travel_to(now) }
    after { travel_back }

    it "creates a trial subscription after user creation" do
      user.save!

      expect(user.subscription).to be_persisted
      expect(user.subscription.source).to eq("wayforpay")
      expect(user.subscription.plan).to eq("trial")
      expect(user.subscription.status).to eq("trialing")
    end

    it "creates a trial lasting exactly 168 hours" do
      user.save!

      expect(user.subscription.trial_ends_at - user.created_at).to eq(168.hours)
    end

    it "sets the expiration from the user creation time" do
      user.save!

      expect(user.subscription.trial_ends_at).to eq(user.created_at + 168.hours)
    end

    it "preserves exactly 168 hours across the winter time transition" do
      user.save!

      expect(user.created_at.in_time_zone("Europe/Kyiv").utc_offset).to eq(3.hours)
      expect(user.subscription.trial_ends_at.in_time_zone("Europe/Kyiv").utc_offset).to eq(2.hours)
      expect(user.subscription.trial_ends_at - user.created_at).to eq(168.hours)
    end

    it "does not create another subscription when user is updated" do
      user.save!

      expect do
        user.update!(name: "Updated Name")
      end.not_to change(Subscription, :count)
    end
  end

  describe "#has_active_subscription?" do
    it "delegates to subscription paid_access?" do
      subscription = instance_spy(Subscription, paid_access?: true)
      allow(user).to receive(:subscription).and_return(subscription)

      expect(user.has_active_subscription?).to be(true)
      expect(subscription).to have_received(:paid_access?).once
    end

    it "returns false without subscription" do
      allow(user).to receive(:subscription).and_return(nil)

      expect(user.has_active_subscription?).to be(false)
    end
  end

  describe "#subscription_will_expire_soon?" do
    it "delegates to subscription expires_soon?" do
      subscription = instance_spy(Subscription, expires_soon?: true)
      allow(user).to receive(:subscription).and_return(subscription)

      expect(user.subscription_will_expire_soon?).to be(true)
      expect(subscription).to have_received(:expires_soon?).once
    end

    it "returns false without subscription" do
      allow(user).to receive(:subscription).and_return(nil)

      expect(user.subscription_will_expire_soon?).to be(false)
    end
  end

  describe "#on_trial?" do
    it "delegates to subscription on_trial?" do
      subscription = instance_spy(Subscription, on_trial?: true)
      allow(user).to receive(:subscription).and_return(subscription)

      expect(user.on_trial?).to be(true)
      expect(subscription).to have_received(:on_trial?).once
    end

    it "returns false without subscription" do
      allow(user).to receive(:subscription).and_return(nil)

      expect(user.on_trial?).to be(false)
    end
  end

  describe "#trial_days_left" do
    it "delegates to subscription trial_days_left" do
      subscription = instance_spy(Subscription, trial_days_left: 5)
      allow(user).to receive(:subscription).and_return(subscription)

      expect(user.trial_days_left).to eq(5)
      expect(subscription).to have_received(:trial_days_left).once
    end

    it "returns 0 without subscription" do
      allow(user).to receive(:subscription).and_return(nil)

      expect(user.trial_days_left).to eq(0)
    end
  end

  describe "#has_write_access?" do
    context "when user is superadmin" do
      it "grants write access" do
        allow(user).to receive(:superadmin?).and_return(true)

        expect(user.has_write_access?).to be(true)
      end
    end

    context "when user has an active subscription" do
      it "grants write access" do
        allow(user).to receive_messages(
          superadmin?: false,
          has_active_subscription?: true,
          on_trial?: false
        )

        expect(user.has_write_access?).to be(true)
      end
    end

    context "when user is on trial" do
      it "grants write access" do
        allow(user).to receive_messages(
          superadmin?: false,
          has_active_subscription?: false,
          on_trial?: true
        )

        expect(user.has_write_access?).to be(true)
      end
    end

    context "when user has no valid access" do
      it "denies write access" do
        allow(user).to receive_messages(
          superadmin?: false,
          has_active_subscription?: false,
          on_trial?: false
        )

        expect(user.has_write_access?).to be(false)
      end
    end
  end

  describe "#subscription_plan" do
    it "returns superadmin for a superadmin user" do
      allow(user).to receive(:superadmin?).and_return(true)

      expect(user.subscription_plan).to eq("superadmin")
    end

    it "returns the current subscription plan" do
      subscription = instance_double(Subscription, plan: "monthly")

      allow(user).to receive_messages(
        superadmin?: false,
        subscription: subscription
      )

      expect(user.subscription_plan).to eq("monthly")
    end

    it "returns none without subscription" do
      allow(user).to receive_messages(
        superadmin?: false,
        subscription: nil
      )

      expect(user.subscription_plan).to eq("none")
    end
  end
end

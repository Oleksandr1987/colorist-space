require "rails_helper"

RSpec.describe Subscription do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user).tap { |u| u.subscription.destroy!; u.reload } }
  let(:now) { Time.zone.local(2026, 9, 22, 12) }

  before do
    travel_to now
  end

  after { travel_back }

  def paid_subscription(**attributes)
    described_class.new({ user: user, plan: "monthly", status: "active",
      current_period_start: now, current_period_end: now + 1.month }.merge(attributes))
  end

  it "keeps purchased access after cancellation" do
    subscription = paid_subscription(status: "cancelled", auto_renew: false, cancelled_at: now)

    expect(subscription.paid_access?).to be(true)
    expect(subscription.display_status).to eq("cancelled")
  end

  it "ends access exactly at the exclusive period end, even if stored status is active" do
    subscription = paid_subscription

    expect(subscription.paid_access?(at: subscription.current_period_end - 1.second)).to be(true)
    expect(subscription.paid_access?(at: subscription.current_period_end)).to be(false)
    expect(subscription.display_status(at: subscription.current_period_end)).to eq("expired")
  end

  it "does not grant access before a scheduled period" do
    expect(paid_subscription(current_period_start: now + 1.day).paid_access?).to be(false)
  end

  it "does not grant access from active status alone" do
    expect(paid_subscription(current_period_end: nil).paid_access?).to be(false)
  end

  it "does not renew a trial after its fixed deadline" do
    subscription =
      described_class.new(user: user, plan: "trial", status: "trialing", trial_ends_at: now + 5.days)

    expect(subscription.trial_days_left).to eq(5)
    expect(subscription.on_trial?(at: now + 5.days)).to be(false)
    expect(subscription.trial_days_left(at: now + 6.days)).to eq(0)
  end

  it "requires provider identity before enabling automatic renewal" do
    subscription = paid_subscription(auto_renew: true)

    expect(subscription).not_to be_valid
    expect(subscription.errors[:wayforpay_order_reference]).to be_present
    expect(subscription.errors[:merchant_account]).to be_present
  end

  it "does not automatically renew a trial" do
    subscription =
    paid_subscription(plan: "trial", auto_renew: true, merchant_account: "merchant", wayforpay_order_reference: "root")
    expect(subscription).not_to be_valid
  end

  it "rejects a reversed period" do
    expect(paid_subscription(current_period_end: now - 1.second)).not_to be_valid
  end

  it "keeps a scheduled plan separate from the currently paid plan" do
    subscription = paid_subscription(next_plan: "yearly", next_plan_starts_at: now + 1.month)

    expect(subscription).to be_valid
    expect(subscription.plan).to eq("monthly")
  end

  it "requires a date for a scheduled plan" do
    expect(paid_subscription(next_plan: "yearly")).not_to be_valid
  end

  it "enforces one subscription per user at the database level" do
    first = paid_subscription
    first.save!

    expect do
      described_class.transaction(requires_new: true) do
        described_class.insert_all!([ { user_id: user.id, plan: "none", status: "pending",
          source: "wayforpay", auto_renew: false, created_at: now, updated_at: now } ])
      end
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end
end

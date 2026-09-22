require "rails_helper"

RSpec.describe Subscriptions::ImportLegacy do
  include ActiveSupport::Testing::TimeHelpers

  let(:now) { Time.zone.local(2026, 9, 22, 12) }

  before do
    travel_to now
  end

  after { travel_back }

  def legacy_user(**attributes)
    create(:user, **attributes).tap { |user| user.subscription.destroy!; user.reload }
  end

  def import(user)
    described_class.new(user).call
    Subscription.find_by!(user_id: user.id)
  end

  it "preserves access throughout the old inclusive expiration date" do
    user = legacy_user(plan_name: "monthly", subscription_expires_at: Date.current)
    subscription = import(user)

    expect(subscription.current_period_end).to eq(Date.tomorrow.in_time_zone.beginning_of_day)
    expect(subscription.paid_access?(at: Date.current.in_time_zone.end_of_day)).to be(true)
    expect(subscription.paid_access?(at: Date.tomorrow.in_time_zone.beginning_of_day)).to be(false)
    expect(subscription.auto_renew?).to be(false)
    expect(subscription.wayforpay_order_reference).to be_nil
    expect(subscription.current_period_start).to be_nil
    expect(subscription.subscription_payments).to be_empty
  end

  it "keeps an unknown paid plan as legacy access without inventing a billing interval" do
    user = legacy_user(plan_name: nil, subscription_expires_at: Date.current + 4.days)

    expect(import(user).plan).to eq("legacy")
  end

  it "does not restart a trial" do
    user = legacy_user(plan_name: "trial", subscription_expires_at: nil, created_at: now - 2.days)
    subscription = import(user)

    expect(subscription.trial_ends_at).to eq(now + 5.days)
    expect(subscription.trial_days_left).to eq(5)
  end

  it "keeps an expired trial expired" do
    user = legacy_user(plan_name: "trial", subscription_expires_at: nil, created_at: now - 20.days)

    expect(import(user).write_access?).to be(false)
  end

  it "does not create paid access for a blank account" do
    user = legacy_user(plan_name: nil, subscription_expires_at: nil)

    expect(import(user).write_access?).to be(false)
  end

  it "can be rerun and updates only legacy records" do
    user = legacy_user(plan_name: "monthly", subscription_expires_at: Date.current + 4.days)

    import(user)

    user.update!(subscription_expires_at: Date.current + 8.days)

    expect { import(user) }.not_to change(Subscription, :count)
    expect(Subscription.find_by!(user_id: user.id).current_period_end)
      .to eq((Date.current + 9.days).in_time_zone.beginning_of_day)
  end

  it "never overwrites a subscription already managed by WayForPay" do
    user = legacy_user(plan_name: "monthly", subscription_expires_at: Date.current + 4.days)
    subscription = Subscription.create!(user: user, source: "wayforpay", plan: "yearly")

    expect(described_class.new(user).call).to eq(:skipped)
    expect(subscription.reload.plan).to eq("yearly")
  end
end

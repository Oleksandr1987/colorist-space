require "rails_helper"
require_relative "../../support/wayforpay_test_config"

RSpec.describe Subscriptions::Reconcile do
  include WayforpayTestConfig
  include ActiveSupport::Testing::TimeHelpers
  let(:subscription) { create(:user).subscription }
  let(:now) { Time.zone.local(2026, 10, 22, 12) }
  let(:status) do
    { "orderReference" => "root", "status" => "Active", "currency" => "UAH",
      "mode" => "monthly", "amount" => "1.0", "lastPayedDate" => now.to_i,
      "lastPayedStatus" => "Approved", "nextPaymentDate" => (now + 1.month).to_i }
  end

  before do
    travel_to now
    configure_wayforpay
    subscription.update!(plan: "monthly", current_period_start: now - 1.month,
      current_period_end: now, merchant_account: "test_merchant",
      wayforpay_order_reference: "root", renewal_amount_minor: 100)
  end

  after { travel_back }

  def apply_status(payload)
    subscription.with_lock { described_class.apply_status(subscription, payload) }
  end

  it "applies a confirmed regular period exactly once" do
    2.times { apply_status(status) }

    expect(subscription.reload.current_period_end).to eq(now + 1.month)
    expect(subscription.subscription_payments.count).to eq(1)
    expect(subscription.subscription_payments.last.source).to eq("regular_status")
  end

  it "does not extend access for failed recurring charges" do
    apply_status(status.merge("lastPayedStatus" => "Declined"))

    expect(subscription.reload.current_period_end).to eq(now)
  end

  it "does not extend a second period from a STATUS of the initial payment" do
    subscription.update!(current_period_end: now + 1.month)

    apply_status(status)

    expect(subscription.subscription_payments.count).to eq(0)
  end

  it "rejects schedule mismatches" do
    expect { apply_status(status.merge("amount" => "9.0")) }.to raise_error(Wayforpay::Error)
    expect(subscription.reload.current_period_end).to eq(now)
  end

  it "does not let a later status read undo local cancellation" do
    subscription.update!(cancelled_at: now, auto_renew: false)

    apply_status(status)

    expect(subscription.reload.auto_renew?).to be(false)
  end

  it "does not grant several years from a malformed next payment date" do
    expect { apply_status(status.merge("nextPaymentDate" => (now + 3.years).to_i)) }.to raise_error(Wayforpay::Error)
  end
end

require "rails_helper"
require_relative "../../support/wayforpay_test_config"

RSpec.describe Subscriptions::Manage do
  include WayforpayTestConfig
  let(:subscription) { create(:user).subscription }
  let(:client) { instance_double(Wayforpay::Client) }

  before do
    configure_wayforpay

    subscription.update!(plan: "monthly", current_period_end: 1.month.from_now,
      merchant_account: "test_merchant", wayforpay_order_reference: "root", auto_renew: true)

    allow(client).to receive(:regular).with("STATUS", "root").and_return(
      "orderReference" => "root", "status" => "Active")
  end

  it "removes future charges while preserving the paid end" do
    ends_at = subscription.current_period_end

    allow(client).to receive(:regular).with("REMOVE", "root").and_return("reasonCode" => 4100)

    described_class.call(subscription, "cancel", client: client)

    expect(subscription.reload.current_period_end).to eq(ends_at)
    expect(subscription.paid_access?).to be(true)
    expect(subscription.auto_renew?).to be(false)
    expect(subscription.management_intent).to be_nil
  end

  it "keeps local renewal state when remote cancellation fails" do
    allow(client).to receive(:regular).with("REMOVE", "root").and_raise(Wayforpay::Error, "timeout")

    expect { described_class.call(subscription, "cancel", client: client) }.to raise_error(Wayforpay::Error)
    expect(subscription.reload.auto_renew?).to be(true)
    expect(subscription.management_intent["action"]).to eq("cancel")
  end

  it "repairs local state after remote REMOVE already succeeded" do
    allow(client).to receive(:regular).with("STATUS", "root").and_return(
      "orderReference" => "root", "status" => "Removed")

    described_class.call(subscription, "cancel", client: client)

    expect(subscription.reload.auto_renew?).to be(false)
    expect(client).not_to have_received(:regular).with("REMOVE", "root")
  end

  it "schedules a change without rewriting the currently paid plan" do
    allow(client).to receive(:regular).with("CHANGE", "root", anything).and_return("reasonCode" => 4100)

    described_class.call(subscription, "change", plan: "yearly", client: client)

    expect(subscription.reload.plan).to eq("monthly")
    expect(subscription.next_plan).to eq("yearly")
    expect(subscription.next_amount_minor).to eq(1000)
  end
end

require "rails_helper"
require_relative "../../support/wayforpay_test_config"

RSpec.describe Subscriptions::ApplyPurchase do
  include WayforpayTestConfig
  let(:user) { create(:user) }
  let(:payment) { Subscriptions::Checkout.call(user, "monthly") }

  before { configure_wayforpay }

  %w[Refunded Voided].each do |status|
    it "records #{status} after approval without clearing idempotency state" do
      described_class.call(payment, approval_for(payment))

      applied_at = payment.reload.processed_at
      end_at = payment.subscription.reload.current_period_end
      payload = approval_for(payment, transactionStatus: status)

      2.times { described_class.call(payment, payload) }

      expect(payment.reload.status).to eq(status.downcase)
      expect(payment.provider_status).to eq(status)
      expect(payment.processed_at).to eq(applied_at)
      expect(payment.subscription.reload.current_period_end).to eq(end_at)
    end
  end

  it "does not reactivate a refunded payment on replayed Approved" do
    described_class.call(payment, approval_for(payment))
    described_class.call(payment, approval_for(payment, transactionStatus: "Refunded"))
    described_class.call(payment, approval_for(payment))

    expect(payment.reload.status).to eq("refunded")
  end

  it "rejects a refund with a mismatched amount" do
    described_class.call(payment, approval_for(payment))

    expect do
      described_class.call(payment, approval_for(payment, transactionStatus: "Refunded", amount: "9"))
    end.to raise_error(Wayforpay::Error)
    expect(payment.reload.status).to eq("approved")
  end
end

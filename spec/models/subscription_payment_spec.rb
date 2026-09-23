require "rails_helper"

RSpec.describe SubscriptionPayment do
  let(:subscription) { create(:user).subscription }
  let(:attributes) do
    { subscription: subscription, merchant_account: "test_merchant",
      order_reference: "checkout_123", plan: "monthly", amount_minor: 100 }
  end

  it "represents one hryvnia exactly" do
    expect(described_class.new(attributes).amount).to eq(BigDecimal("1.00"))
  end

  it "rejects zero and negative amounts" do
    expect(described_class.new(attributes.merge(amount_minor: 0))).not_to be_valid
    expect(described_class.new(attributes.merge(amount_minor: -1))).not_to be_valid
  end

  it "rejects duplicate merchant/order pairs" do
    described_class.create!(attributes)

    duplicate = described_class.new(attributes)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:order_reference]).to be_present
  end

  it "keeps test and production merchant namespaces separate" do
    described_class.create!(attributes)

    expect(described_class.new(attributes.merge(merchant_account: "production_merchant"))).to be_valid
  end

  it "does not confuse provider approval with applied access" do
    payment = described_class.new(attributes.merge(status: "approved", paid_at: Time.current))

    expect(payment.processed?).to be(false)

    payment.processed_at = Time.current

    expect(payment.processed?).to be(true)
  end

  it "does not store card tokens, signatures, email or card details as callback metadata" do
    payment = described_class.new(attributes)

    payment.assign_callback_metadata({ "orderReference" => "checkout_123", "recToken" => "token",
      "merchantSignature" => "signature", "email" => "payer@example.com", "cardPan" => "masked" })

    expect(payment.callback_metadata).to eq("orderReference" => "checkout_123")
  end

  it "preserves payment history when a subscription is destroyed" do
    described_class.create!(attributes)

    expect(subscription.destroy).to be(false)
    expect(subscription.reload).to be_persisted
  end
end

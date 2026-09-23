module WayforpayTestConfig
  def configure_wayforpay
    values = { merchant_account: "test_merchant", secret_key: "test-secret",
      merchant_password: "test-password", public_base_url: "https://dev.colorist.space",
      merchant_domain: "dev.colorist.space", monthly_amount_minor: 100,
      yearly_amount_minor: 1000, demo: "true" }

    allow(Wayforpay::Config).to receive(:get) { |key, default = nil| values.fetch(key, default) }
  end

  def approval_for(payment, **overrides)
    payload = {
      "merchantAccount" => payment.merchant_account, "orderReference" => payment.order_reference,
      "amount" => payment.amount.to_s("F"), "currency" => "UAH", "authCode" => "AUTH123",
      "cardPan" => "4111****1111", "transactionStatus" => "Approved", "reasonCode" => "1100"
    }.merge(overrides.stringify_keys)

    fields = Wayforpay::Webhook::SIGNED_FIELDS.map { |key| payload[key] }

    payload["merchantSignature"] = Wayforpay::Signature.generate(fields, Wayforpay::Config.secret)

    payload
  end
end

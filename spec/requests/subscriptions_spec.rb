require "rails_helper"
require_relative "../support/wayforpay_test_config"

RSpec.describe "Subscriptions" do
  include Devise::Test::IntegrationHelpers
  include WayforpayTestConfig
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, :trial) }

  before { configure_wayforpay }

  it "requires login for checkout" do
    post monthly_subscription_path

    expect(response).to have_http_status(:redirect)
    expect(SubscriptionPayment.count).to eq(0)
  end

  it "creates and reuses one stored checkout" do
    sign_in user

    2.times { post monthly_subscription_path }

    expect(response).to have_http_status(:ok)
    expect(user.subscription.subscription_payments.count).to eq(1)
    expect(response.body).to include('https://secure.wayforpay.com/pay')
    expect(response.body).to include('data-turbo="false"')

    form = Nokogiri::HTML(response.body).at_css('form[action="https://secure.wayforpay.com/pay"]')
    expect(form.at_css('input[name="authenticity_token"]')).to be_nil
  end

  it "prevents a second agreement while paid access exists" do
    user.subscription.update!(plan: "monthly", current_period_end: 1.month.from_now)

    sign_in user

    expect { post yearly_subscription_path }.not_to change(SubscriptionPayment, :count)
  end

  it "handles a signed callback without a login or modern browser" do
    payment = Subscriptions::Checkout.call(user, "monthly")

    post payment_callback_subscription_path, params: approval_for(payment), as: :json, headers: { "User-Agent" => "WayForPay" }

    expect(response).to have_http_status(:ok)

    data = response.parsed_body

    expect(data["status"]).to eq("accept")
    expect(data["signature"]).to eq(Wayforpay::Signature.generate(
      [ data["orderReference"], "accept", data["time"] ], Wayforpay::Config.secret))
    expect(user.reload.has_active_subscription?).to be(true)
    expect(user.subscription.auto_renew?).to be(false)
  end

  it "parses raw JSON sent with a form content type" do
    payment = Subscriptions::Checkout.call(user, "monthly")

    post payment_callback_subscription_path, params: approval_for(payment).to_json,
      headers: { "CONTENT_TYPE" => "application/x-www-form-urlencoded" }

    expect(response).to have_http_status(:ok)
  end

  it "does not extend access when approval is replayed the next day" do
    payment = Subscriptions::Checkout.call(user, "monthly")
    payload = approval_for(payment)

    post payment_callback_subscription_path, params: payload, as: :json

    ends_at = user.reload.subscription.current_period_end

    travel 1.day do
      post payment_callback_subscription_path, params: payload, as: :json
    end

    expect(user.reload.subscription.current_period_end).to eq(ends_at)
    expect(WayforpayEvent.count).to eq(1)
  end

  it "does not trust the callback email to select another user" do
    other = create(:user)
    payment = Subscriptions::Checkout.call(user, "monthly")

    post payment_callback_subscription_path,
      params: approval_for(payment).merge("clientEmail" => other.email), as: :json

    expect(user.reload.has_active_subscription?).to be(true)
    expect(other.reload.has_active_subscription?).to be(false)
  end

  it "rejects a wrong amount even with a valid signature" do
    payment = Subscriptions::Checkout.call(user, "yearly")

    post payment_callback_subscription_path, params: approval_for(payment, amount: "1"), as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(user.reload.has_active_subscription?).to be(false)
  end

  it "rejects an invalid signature" do
    payment = Subscriptions::Checkout.call(user, "monthly")

    post payment_callback_subscription_path,
      params: approval_for(payment).merge("merchantSignature" => "invalid"), as: :json

    expect(response).to have_http_status(:forbidden)
    expect(WayforpayEvent.count).to eq(0)
  end

  it "rejects a different merchant even when signed by this test key" do
    payment = Subscriptions::Checkout.call(user, "monthly")

    post payment_callback_subscription_path,
      params: approval_for(payment, merchantAccount: "someone_else"), as: :json

    expect(response).to have_http_status(:forbidden)
  end

  it "records an unknown reference without granting access" do
    payment = Subscriptions::Checkout.call(user, "monthly")

    post payment_callback_subscription_path,
      params: approval_for(payment, orderReference: "provider-renewal-unknown"), as: :json

    expect(response).to have_http_status(:ok)
    expect(WayforpayEvent.last.state).to eq("unmatched")
    expect(user.reload.has_active_subscription?).to be(false)
  end

  it "does not activate a declined purchase" do
    payment = Subscriptions::Checkout.call(user, "monthly")

    post payment_callback_subscription_path,
      params: approval_for(payment, transactionStatus: "Declined", reasonCode: "1105"), as: :json

    expect(user.reload.has_active_subscription?).to be(false)
    expect(payment.reload.status).to eq("declined")
  end

  it "never activates from the browser return" do
    post payment_return_subscription_path, params: { transactionStatus: "Approved" }

    expect(response).to have_http_status(:see_other)
    expect(user.has_active_subscription?).to be(false)
  end

  it "blocks checkout for superadmin on the server" do
    sign_in create(:user, :superadmin)

    post monthly_subscription_path
    expect(response).to have_http_status(:forbidden)
  end
end


# frozen_string_literal: true

require "rails_helper"
require_relative "../support/wayforpay_test_config"

RSpec.describe "Wayforpay callbacks" do
  include WayforpayTestConfig

  before { configure_wayforpay }

  describe "POST /subscription/payment_callback" do
    let(:path) { payment_callback_subscription_path }

    it "accepts a valid signed JSON callback without authentication" do
      user = create(:user, :trial)
      payment = Subscriptions::Checkout.call(user, "monthly")

      post path, params: approval_for(payment), as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["status"]).to eq("accept")
      expect(user.reload.has_active_subscription?).to be(true)
    end

    it "accepts a valid form-urlencoded callback" do
      user = create(:user, :trial)
      payment = Subscriptions::Checkout.call(user, "monthly")

      post path, params: approval_for(payment)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["status"]).to eq("accept")
      expect(user.reload.has_active_subscription?).to be(true)
    end

    it "rejects a callback with an invalid signature" do
      user = create(:user, :trial)
      payment = Subscriptions::Checkout.call(user, "monthly")
      payload = approval_for(payment).merge("merchantSignature" => "invalid")

      post path, params: payload, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(user.reload.has_active_subscription?).to be(false)
    end

    it "returns internal server error when body-limit middleware is missing" do
      allow(Rails.logger).to receive(:error)
      allow(Wayforpay::Webhook).to receive(:call)

      rack_response = Rack::MockRequest.new(Rails.application.routes).post(
        payment_callback_subscription_path,
        "CONTENT_TYPE" => "application/json",
        input: { merchantAccount: "test_merchant" }.to_json
      )

      expect(rack_response.status).to eq(500)
      expect(Rails.logger).to have_received(:error).with("WayForPay body-limit middleware is missing")
      expect(Wayforpay::Webhook).not_to have_received(:call)
    end


    it "returns bad request for malformed JSON" do
      post path, params: '{"merchantAccount":', headers: { "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:bad_request)
    end

    it "returns bad request when JSON parsing fails inside the controller" do
      allow(JSON).to receive(:parse).and_raise(JSON::ParserError, "Invalid JSON")

      post path, params: '{"merchantAccount":"test_merchant"}', headers: { "CONTENT_TYPE" => "text/plain" }

      expect(JSON).to have_received(:parse)
      expect(response).to have_http_status(:bad_request)
    end

    it "returns bad request for parameter parsing errors" do
      allow(Wayforpay::Webhook).to receive(:call)
        .and_raise(ActionDispatch::Http::Parameters::ParseError.new("Invalid parameters"))

      post path, params: { merchantAccount: "test_merchant" }, as: :json

      expect(Wayforpay::Webhook).to have_received(:call)
      expect(response).to have_http_status(:bad_request)
    end

    it "returns unprocessable content when Wayforpay raises an error" do
      allow(Wayforpay::Webhook).to receive(:call).and_raise(Wayforpay::Error, "Payment processing failed")
      allow(Rails.logger).to receive(:warn)

      post path, params: { merchantAccount: "test_merchant" }, as: :json

      expect(Wayforpay::Webhook).to have_received(:call)
      expect(Rails.logger).to have_received(:warn).with("WayForPay callback: Payment processing failed")
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /subscription/payment_return" do
    it "redirects to subscription settings" do
      get payment_return_subscription_path

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(settings_subscription_path(locale: I18n.default_locale))
    end
  end

  describe "POST /subscription/payment_return" do
    it "does not activate a subscription from browser parameters" do
      user = create(:user, :trial)

      post payment_return_subscription_path, params: { transactionStatus: "Approved" }

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(settings_subscription_path(locale: I18n.default_locale))
      expect(user.reload.has_active_subscription?).to be(false)
    end
  end
end

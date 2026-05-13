require "rails_helper"

RSpec.describe "Subscriptions" do
  include Devise::Test::IntegrationHelpers

  let(:user) do
    create(
      :user,
      :trial,
      email: "test@example.com",
      name: "Oleksandr"
    )
  end

  before do
    sign_in user, scope: :user
  end

  describe "POST /monthly" do
    it "renders payment form for monthly plan" do
      post monthly_subscription_path

      expect(response).to have_http_status(:ok)

      expect(response.body)
        .to include("Colorist Space – підписка на 1 місяць")
    end
  end

  describe "POST /yearly" do
    it "renders payment form for yearly plan" do
      post yearly_subscription_path

      expect(response).to have_http_status(:ok)

      expect(response.body)
        .to include("Colorist Space – підписка на 1 рік")
    end
  end

  describe "DELETE /cancel" do
    before do
      user.update!(
        plan_name: "monthly",
        subscription_expires_at: 1.month.from_now
      )
    end

    it "clears subscription data" do
      delete cancel_subscription_path

      expect(user.reload.plan_name).to be_nil
      expect(user.reload.subscription_expires_at).to be_nil
    end

    it "redirects to settings subscription page" do
      delete cancel_subscription_path

      expect(response).to redirect_to(
        settings_subscription_path(locale: I18n.locale)
      )
    end
  end

  describe "POST /payment_callback" do
    let(:order_reference) { "monthly_test123" }

    let(:signature_fields) do
      [
        "merchant",
        order_reference,
        "1",
        "UAH",
        "AUTH123",
        "444455XXXXXX1111",
        "Approved",
        "1100"
      ]
    end

    let(:signature) do
      Wayforpay::Signature.generate(
        signature_fields,
        SubscriptionsController::SECRET_KEY
      )
    end

    let(:valid_params) do
      {
        merchantAccount: "merchant",
        orderReference: order_reference,
        amount: "1",
        currency: "UAH",
        authCode: "AUTH123",
        cardPan: "444455XXXXXX1111",
        transactionStatus: "Approved",
        reasonCode: "1100",
        merchantSignature: signature,
        clientEmail: user.email
      }
    end

    it "activates monthly subscription when payment approved" do
      post payment_callback_subscription_path,
           params: valid_params

      expect(response).to have_http_status(:ok)

      expect(user.reload.plan_name).to eq("monthly")
      expect(user.subscription_expires_at).to be_present
    end

    it "activates yearly subscription" do
      valid_params[:orderReference] = "yearly_test123"

      yearly_signature_fields = [
        "merchant",
        "yearly_test123",
        "1",
        "UAH",
        "AUTH123",
        "444455XXXXXX1111",
        "Approved",
        "1100"
      ]

      valid_params[:merchantSignature] =
        Wayforpay::Signature.generate(
          yearly_signature_fields,
          SubscriptionsController::SECRET_KEY
        )

      post payment_callback_subscription_path,
           params: valid_params

      expect(user.reload.plan_name).to eq("yearly")
    end

    it "returns forbidden for invalid signature" do
      valid_params[:merchantSignature] = "invalid"

      post payment_callback_subscription_path,
           params: valid_params

      expect(response).to have_http_status(:forbidden)
    end

    it "does not activate subscription when status not approved" do
      valid_params[:transactionStatus] = "Declined"

      declined_signature_fields = [
        "merchant",
        order_reference,
        "1",
        "UAH",
        "AUTH123",
        "444455XXXXXX1111",
        "Declined",
        "1100"
      ]

      valid_params[:merchantSignature] =
        Wayforpay::Signature.generate(
          declined_signature_fields,
          SubscriptionsController::SECRET_KEY
        )

      post payment_callback_subscription_path,
           params: valid_params

      expect(user.reload.plan_name).to eq("trial")
    end

    it "returns ok even if user not found" do
      valid_params[:clientEmail] = "missing@example.com"

      post payment_callback_subscription_path,
           params: valid_params

      expect(response).to have_http_status(:ok)
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users::Registrations" do
  include Devise::Test::IntegrationHelpers
  describe "POST /users" do
    let(:valid_password) { "Password1!" }

    let(:valid_params) do
      {
        user: {
          name: "Ivan",
          email: "ivan@example.com",
          phone: "+38(095) 097 41 65",
          password: valid_password,
          password_confirmation: valid_password,
          tos_agreement: "1"
        }
      }
    end

    it "creates a user with a normalized phone number" do
      expect { post user_registration_path, params: valid_params }.to change(User, :count).by(1)
      expect(User.last.phone).to eq("+380950974165")
    end

    context "when phone is already registered" do
      before { create(:user, phone: "+380950974165") }

      it "does not create another user" do
        expect { post user_registration_path, params: valid_params }.not_to change(User, :count)
      end

      it "returns a validation error instead of raising RecordNotUnique" do
        post user_registration_path, params: valid_params

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("phone")
      end
    end
  end

  describe "PATCH /users" do
    let(:password) { "Password1!" }
    let(:user) { create(:user,  password: password,  password_confirmation: password) }

    before { sign_in user }

    it "updates permitted account attributes" do
      patch user_registration_path, params: { user: { name: "Updated Name", current_password: password } }

      expect(response).to have_http_status(:see_other)
      expect(user.reload.name).to eq("Updated Name")
    end


    it "rejects account updates with an incorrect current password" do
      patch user_registration_path, params: { user: { name: "Updated Name", current_password: "WrongPassword1!" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.name).not_to eq("Updated Name")
    end
  end

  describe "DELETE /users" do
    let(:user) { create(:user, :trial) }

    before { sign_in user }

    it "deletes a user without a subscription" do
      user.subscription&.destroy!
      user.reload

      expect(user.subscription).to be_nil
      expect { delete user_registration_path }.to change(User, :count).by(-1)
      expect(response).to have_http_status(:see_other)
      expect(User.exists?(user.id)).to be(false)
    end

    it "deletes a user with an unused trial subscription" do
      subscription_id = user.subscription.id

      expect { delete user_registration_path }.to change(User, :count).by(-1).and change(Subscription, :count).by(-1)
      expect(Subscription.exists?(subscription_id)).to be(false)
      expect(response).to have_http_status(:see_other)
    end

    it "blocks deletion when paid access is active" do
      user.subscription.update!(plan: "monthly", status: "active", current_period_end: 1.month.from_now)

      expect { delete user_registration_path }.not_to change(User, :count)
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(settings_subscription_path(locale: I18n.locale))
      expect(flash[:alert]).to eq(I18n.t("subscription.account_deletion_blocked"))
    end


    it "blocks deletion when payment history exists" do
      subscription = user.subscription

      subscription.update!(plan: "none", status: "expired", current_period_end: 1.day.ago, wayforpay_order_reference: nil)

      payment = create(:subscription_payment, subscription: subscription)

      expect { delete user_registration_path }.not_to change(User, :count)
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(settings_subscription_path(locale: I18n.locale))
      expect(flash[:alert]).to eq(I18n.t("subscription.account_deletion_blocked"))
      expect(User.exists?(user.id)).to be(true)
      expect(Subscription.exists?(subscription.id)).to be(true)
      expect(SubscriptionPayment.exists?(payment.id)).to be(true)
    end


    it "blocks deletion when a WayForPay agreement exists" do
      user.subscription.update!(wayforpay_order_reference: "WFP-AGREEMENT-123")

      expect { delete user_registration_path }.not_to change(User, :count)
      expect(response).to have_http_status(:see_other)
      expect(flash[:alert]).to eq(I18n.t("subscription.account_deletion_blocked"))
    end
  end
end

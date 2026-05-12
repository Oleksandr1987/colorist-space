require "rails_helper"

RSpec.describe "Users::Sessions", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:password) { "Password123!" }

  let(:user) do
    create(
      :user,
      email: "test@example.com",
      phone: "+380991112233",
      password: password,
      password_confirmation: password
    )
  end

  describe "POST /users/sign_in" do
    it "signs in with email" do
      post user_session_path, params: {
        user: {
          login: user.email,
          password: password
        }
      }

      expect(response).to redirect_to(
        calendar_appointments_path(locale: I18n.locale)
      )
    end

    it "normalizes phone before sign in" do
      allow(PhoneValidator)
        .to receive(:normalize)
        .and_call_original

      post user_session_path, params: {
        user: {
          login: "0991112233",
          password: password
        }
      }

      expect(PhoneValidator)
        .to have_received(:normalize)
        .with("0991112233")
        .at_least(:once)
    end

    it "signs in with normalized phone" do
      normalized_phone = PhoneValidator.normalize("0991112233")

      user.update_column(:phone, normalized_phone)

      post user_session_path, params: {
        user: {
          login: "0991112233",
          password: password
        }
      }

      expect(response).to redirect_to(
        calendar_appointments_path(locale: I18n.locale)
      )
    end

    it "signs in with email without normalization" do
      post user_session_path, params: {
        user: {
          login: user.email,
          password: password
        }
      }

      expect(response).to redirect_to(
        calendar_appointments_path(locale: I18n.locale)
      )
    end

    it "does not fail when user params missing" do
      expect do
        post user_session_path, params: {}
      end.not_to raise_error
    end

    it "does not fail when login missing" do
      expect do
        post user_session_path, params: {
          user: {
            password: password
          }
        }
      end.not_to raise_error
    end

    it "renders new with invalid password" do
      post user_session_path, params: {
        user: {
          login: user.email,
          password: "wrong-password"
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /users/sign_out" do
    it "redirects to root path" do
      sign_in user

      delete destroy_user_session_path

      expect(response).to redirect_to(
        root_path(locale: I18n.locale)
      )
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users::Registrations" do
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
      expect {
        post user_registration_path, params: valid_params
      }.to change(User, :count).by(1)

      expect(User.last.phone).to eq("+380950974165")
    end

    context "when phone is already registered" do
      before do
        create(:user, phone: "+380950974165")
      end

      it "does not create another user" do
        expect {
          post user_registration_path, params: valid_params
        }.not_to change(User, :count)
      end

      it "returns a validation error instead of raising RecordNotUnique" do
        post user_registration_path, params: valid_params

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("phone")
      end
    end
  end
end

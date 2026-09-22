# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Home" do
  include Devise::Test::IntegrationHelpers

  describe "GET /" do
    context "when user is not signed in" do
      it "returns a successful response" do
        get root_path

        expect(response).to have_http_status(:ok)
      end
    end

    context "when user is signed in" do
      let(:user) { create(:user) }

      before do
        sign_in user
      end

      it "redirects to the appointments calendar" do
        get root_path

        expect(response).to redirect_to(calendar_appointments_path(locale: I18n.locale))
      end
    end
  end
end

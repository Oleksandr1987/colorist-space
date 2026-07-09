require "rails_helper"

RSpec.describe "Static pages" do
  describe "GET /privacy_policy" do
    it "renders privacy policy page" do
      get "/privacy_policy"

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /terms" do
    it "renders terms page" do
      get "/terms"

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /about_us" do
    it "renders about us page" do
      get "/about_us"

      expect(response).to have_http_status(:ok)
    end
  end
end

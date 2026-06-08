require "rails_helper"

RSpec.describe "Services" do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user, :trial) }

  before do
    sign_in user, scope: :user
  end

  describe "GET /services/new" do
    it "renders page" do
      get new_service_path

      expect(response).to have_http_status(:ok)
    end

    it "sets category from params" do
      get new_service_path, params: {
        category: "Haircut"
      }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /services/main" do
    it "returns success" do
      create(:service, user: user)

      get main_services_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /services/section" do
    it "returns success" do
      create(:service, user: user, category: "haircut")

      get section_services_path(category: "haircut")

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /services/care_products" do
    it "returns success" do
      create(:service, :care_product, user: user)

      get care_products_services_path

      expect(response).to have_http_status(:ok)
    end

    it "builds new service when new param passed" do
      get care_products_services_path, params: { new: "true" }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /services" do
    it "creates service" do
      expect {
        post services_path, params: {
          service: {
            category: "Haircut",
            subtype: "Fade",
            price: 500,
            service_type: "service"
          }
        }
      }.to change(Service, :count).by(1)

      expect(response).to redirect_to(
        section_services_path(category: "haircut")
      )
    end

    it "renders new when invalid" do
      post services_path, params: {
        service: {
          subtype: "",
          price: nil
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /services/:id" do
    it "updates service" do
      service = create(:service, user: user)

      patch service_path(service), params: {
        service: {
          subtype: "Updated",
          price: 999,
          category: "Coloring"
        }
      }

      expect(response).to redirect_to(
        section_services_path(
          category: "Coloring",
          locale: I18n.locale
        )
      )

      expect(service.reload.subtype).to eq("Updated")
    end

    it "renders edit when invalid" do
      service = create(:service, user: user)

      patch service_path(service), params: {
        service: {
          subtype: "",
          price: nil
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /services/:id" do
    it "destroys regular service" do
      service = create(:service, user: user)

      expect {
        delete service_path(service)
      }.to change(Service, :count).by(-1)

      expect(response).to redirect_to(
        section_services_path(category: service.category)
      )
    end

    it "destroys care product" do
      service = create(:service, :care_product, user: user)

      delete service_path(service)

      expect(response).to redirect_to(
        care_products_services_path(locale: I18n.locale)
      )
    end
  end

  describe "POST /services/create_care_product" do
    it "creates care product" do
      expect {
        post create_care_product_services_path, params: {
          service: {
            subtype: "Mask",
            price: 300,
            unit: "pcs"
          }
        }
      }.to change(Service, :count).by(1)

      expect(response).to redirect_to(
        care_products_services_path(locale: I18n.locale)
      )
    end

    it "creates care product json" do
      post create_care_product_services_path,
        params: {
          service: {
            subtype: "Mask",
            price: 300,
            unit: "pcs"
          }
        },
        as: :json

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)

      expect(body["name"]).to eq("Mask")
    end

    it "renders errors when invalid" do
      post create_care_product_services_path, params: {
        service: {
          subtype: "",
          price: nil
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "additional branches" do
    it "redirects to care products after update" do
      service = create(:service, :care_product, user: user)

      patch service_path(service), params: {
        service: {
          subtype: "Updated Care",
          price: 300
        }
      }

      expect(response).to redirect_to(
        care_products_services_path(locale: I18n.locale)
      )
    end

    it "falls back to services path for unknown type" do
      service = create(:service, user: user)

      service.update_column(:service_type, "unknown")

      delete service_path(service)

      expect(response).to redirect_to(
        services_path(locale: I18n.locale)
      )
    end

    it "normalizes lowercase category" do
      post services_path, params: {
        service: {
          category: "haircut",
          subtype: "Buzz",
          price: 100,
          service_type: "service"
        }
      }

      expect(Service.last.category).to eq("haircut")
    end

    it "normalizes translated category name" do
      translated = I18n.t("services.categories.haircut")

      post services_path, params: {
        service: {
          category: translated,
          subtype: "Classic",
          price: 250,
          service_type: "service"
        }
      }

      expect(Service.last.category).to eq("haircut")
    end

    it "keeps custom category unchanged" do
      post services_path, params: {
        service: {
          category: "CustomCategory",
          subtype: "Custom",
          price: 100,
          service_type: "service"
        }
      }

      expect(Service.last.category).to eq("CustomCategory")
    end
  end
end

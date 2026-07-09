require "rails_helper"

RSpec.describe "CareProducts" do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user, :trial) }

  before do
    sign_in user, scope: :user
  end

  describe "GET /care_products" do
    it "returns success" do
      create(:care_product, user: user)

      get care_products_path

      expect(response).to have_http_status(:ok)
    end

    it "builds new care product when new param passed" do
      get care_products_path, params: {
        new: "true"
      }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /care_products/new" do
    it "renders page" do
      get new_care_product_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /care_products" do
    it "creates care product" do
      expect do
        post care_products_path,
             params: {
               care_product: {
                 brand: "Londa",
                 name: "Shampoo",
                 category: "Shampoo",
                 purchase_price: 200,
                 sale_price: 350,
                 stock_quantity: 10
               }
             }
      end.to change(CareProduct, :count).by(1)

      expect(response).to redirect_to(
        care_products_path(locale: I18n.locale)
      )
    end

    it "creates care product json" do
      post care_products_path,
           params: {
             care_product: {
               name: "Mask",
               sale_price: 300
             }
           },
           as: :json

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)

      expect(body["name"]).to eq("Mask")
      expect(body["sale_price"]).to eq(300)
    end

    it "renders errors when invalid" do
      post care_products_path,
           params: {
             care_product: {
               name: ""
             }
           }

      expect(response).to have_http_status(
        :unprocessable_content
      )
    end
  end

  describe "PATCH /care_products/:id" do
    it "updates care product" do
      care_product =
        create(
          :care_product,
          user: user,
          name: "Old Name"
        )

      patch care_product_path(care_product),
            params: {
              care_product: {
                name: "New Name"
              }
            }

      expect(response).to redirect_to(
        care_products_path(locale: I18n.locale)
      )

      expect(
        care_product.reload.name
      ).to eq("New Name")
    end

    it "renders edit when invalid" do
      care_product =
        create(
          :care_product,
          user: user
        )

      patch care_product_path(care_product),
            params: {
              care_product: {
                name: ""
              }
            }

      expect(response).to have_http_status(
        :unprocessable_content
      )
    end
  end

  describe "DELETE /care_products/:id" do
    it "destroys care product" do
      care_product =
        create(
          :care_product,
          user: user
        )

      expect do
        delete care_product_path(care_product)
      end.to change(CareProduct, :count).by(-1)

      expect(response).to redirect_to(
        care_products_path(locale: I18n.locale)
      )
    end
  end
end

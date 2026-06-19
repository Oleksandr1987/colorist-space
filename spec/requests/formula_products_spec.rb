require "rails_helper"

RSpec.describe "FormulaProducts" do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user, :trial) }

  before do
    sign_in user, scope: :user
  end

  describe "GET /formula_products" do
    it "returns colors by default" do
      create(:formula_product, user: user, category: "color")
      create(:formula_product, :oxidant, user: user)

      get formula_products_path

      expect(response).to have_http_status(:ok)
    end

    it "filters by category" do
      create(:formula_product, :oxidant, user: user)

      get formula_products_path(
        category: "oxidant"
      )

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /formula_products/new" do
    it "renders page" do
      get new_formula_product_path(
        category: "color"
      )

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /formula_products" do
    it "creates formula product" do
      expect {
        post formula_products_path, params: {
          formula_product: {
            category: "color",
            brand: "Wella",
            name: "Koleston 7/1",
            unit: "g",
            price_per_unit: 15
          }
        }
      }.to change(
        FormulaProduct,
        :count
      ).by(1)

      expect(response).to redirect_to(
        formula_products_path(
          category: "color"
        )
      )
    end

    it "creates formula product as json" do
      post formula_products_path,
           params: {
             formula_product: {
               category: "color",
               brand: "Wella",
               name: "Koleston 7/1",
               unit: "g",
               price_per_unit: 15
             }
           },
           as: :json

      expect(response).to have_http_status(:ok)
    end

    it "renders new when invalid" do
      post formula_products_path, params: {
        formula_product: {
          category: "color",
          brand: "",
          name: "",
          unit: "g",
          price_per_unit: 15
        }
      }

      expect(response).to have_http_status(
        :unprocessable_content
      )
    end
  end

  describe "PATCH /formula_products/:id" do
    it "updates formula product" do
      product = create(
        :formula_product,
        user: user
      )

      patch formula_product_path(product),
            params: {
              formula_product: {
                name: "Updated",
                brand: "Loreal"
              }
            }

      expect(response).to redirect_to(
        formula_products_path(
          category: product.category
        )
      )

      expect(
        product.reload.name
      ).to eq("Updated")
    end

    it "renders edit when invalid" do
      product = create(
        :formula_product,
        user: user
      )

      patch formula_product_path(product),
            params: {
              formula_product: {
                brand: "",
                name: ""
              }
            }

      expect(response).to have_http_status(
        :unprocessable_content
      )
    end
  end

  describe "DELETE /formula_products/:id" do
    it "destroys formula product" do
      product = create(
        :formula_product,
        user: user
      )

      expect {
        delete formula_product_path(product)
      }.to change(
        FormulaProduct,
        :count
      ).by(-1)

      expect(response).to redirect_to(
        formula_products_path(
          category: product.category
        )
      )
    end
  end
end

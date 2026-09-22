require "rails_helper"

RSpec.describe "FormulaProducts" do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user, :trial) }

  before do
    sign_in user, scope: :user
  end

  describe "GET /formula_products" do
    it "returns all formula products for current user" do
      color = create(:formula_product, user: user, category: "color")
      oxidant = create(:formula_product, user: user, category: "oxidant")

      get formula_products_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(color.name)
      expect(response.body).to include(oxidant.name)
    end

    it "does not return formula products belonging to another user" do
      other_user = create(:user, :trial)
      own_product = create(:formula_product, user: user, name: "Own product")
      other_product = create(:formula_product, user: other_user, name: "Other product")

      get formula_products_path

      expect(response.body).to include(own_product.name)
      expect(response.body).not_to include(other_product.name)
    end
  end

  describe "GET /formula_products/new" do
    it "renders page" do
      get new_formula_product_path(category: "color")

      expect(response).to have_http_status(:ok)
    end

    it "builds a color product from category param" do
      get new_formula_product_path(category: "color")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('value="color"')
    end

    it "builds an oxidant product from category param" do
      get new_formula_product_path(category: "oxidant")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('value="oxidant"')
    end
  end

  describe "GET /formula_products/:id/edit" do
    it "renders edit page" do
      product = create(:formula_product, user: user)

      get edit_formula_product_path(product)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /formula_products" do
    let(:valid_params) do
      { formula_product: { category: "color", brand: "Wella", name: "Koleston 7/1", unit: "g", price_per_unit: 15 } }
    end

    it "creates formula product" do
      expect { post formula_products_path, params: valid_params }.to change(FormulaProduct, :count).by(1)

      expect(response).to redirect_to(formula_products_path(category: "color", locale: I18n.locale))
    end

    it "redirects back to oxidants after creating an oxidant" do
      post formula_products_path, params:
          { formula_product: { category: "oxidant", brand: "Wella", name: "Developer 6%", unit: "ml", price_per_unit: 2 } }

      expect(response).to redirect_to(formula_products_path(category: "oxidant", locale: I18n.locale))
    end

    it "assigns created product to current user" do
      post formula_products_path, params: valid_params

      expect(FormulaProduct.last.user).to eq(user)
    end

    it "creates formula product as json" do
      post formula_products_path, params: valid_params, as: :json

      expect(response).to have_http_status(:ok)

      json = response.parsed_body

      expect(json).to include("id" => kind_of(Integer), "brand" => "Wella", "unit" => "g")
      expect(json["price_per_unit"].to_d).to eq(15.to_d)
    end

    it "renders new when invalid" do
      expect { post formula_products_path,
        params: { formula_product: { category: "color", brand: "", name: "", unit: "g", price_per_unit: 15 } }
      }.not_to change(FormulaProduct, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns errors as json when invalid" do
      expect { post formula_products_path,
        params: { formula_product: { category: "color", brand: "", unit: "g", price_per_unit: 15 } }, as: :json
      }.not_to change(FormulaProduct, :count)

      expect(response).to have_http_status(:unprocessable_content)

      json = response.parsed_body

      expect(json["errors"]).to be_present
    end
  end

  describe "PATCH /formula_products/:id" do
    it "updates formula product" do
      product = create(:formula_product, user: user)

      patch formula_product_path(product), params: { formula_product: { name: "Updated", brand: "Loreal" } }

      expect(response).to redirect_to(formula_products_path(category: product.reload.category, locale: I18n.locale))

      expect(product.name).to eq("Updated")
      expect(product.brand).to eq("Loreal")
    end

    it "does not update formula product when invalid" do
      product = create(:formula_product, user: user, brand: "Wella")

      patch formula_product_path(product), params: { formula_product: { brand: "" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(product.reload.brand).to eq("Wella")
    end
  end

  describe "DELETE /formula_products/:id" do
    it "destroys formula product" do
      product = create(:formula_product, user: user)
      category = product.category

      expect { delete formula_product_path(product) }.to change(FormulaProduct, :count).by(-1)

      expect(response).to redirect_to(formula_products_path(category: category, locale: I18n.locale))
    end
  end
end

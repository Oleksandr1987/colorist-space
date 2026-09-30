require "rails_helper"

RSpec.describe "CareProducts" do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user, :trial) }
  let(:care_product) { create(:care_product, user: user) }

  before { sign_in user, scope: :user }

  describe "GET /care_products" do
    it "returns success" do
      care_product

      get care_products_path

      expect(response).to have_http_status(:ok)
    end

    it "builds new care product when new param passed" do
      get care_products_path, params: { new: "true" }

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
    let(:product_params) do
      { brand: "Londa", name: "Shampoo", category: "Shampoo", purchase_price: 200, sale_price: 350, stock_quantity: 10 }
    end

    let(:opening_balance_params) { product_params.merge(purchased_on: Date.current.iso8601) }

    it "creates care product" do
      expect { post care_products_path, params: { care_product: product_params } }.to change(CareProduct, :count).by(1)
      expect(response).to redirect_to(care_products_path(locale: I18n.locale))
    end

    it "creates care product json" do
      post care_products_path, params: { care_product: { name: "Mask", sale_price: 300 } }, as: :json

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)

      expect(body["name"]).to eq("Mask")
      expect(body["sale_price"]).to eq(300)
    end

    it "renders errors when invalid" do
      post care_products_path, params: { care_product: { name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "creates opening balance for initial stock" do
      expect { post care_products_path, params: { care_product: opening_balance_params } }
        .to change { user.care_product_stock_movements.count }.by(1)

      movement = user.care_product_stock_movements.last

      expect(movement.movement_type).to eq("opening_balance")
      expect(movement.quantity).to eq(10)
    end

    it "creates expense for initial stock with purchase price" do
      expect { post care_products_path, params: { care_product: opening_balance_params } }.to change { user.expenses.count }.by(1)
      expect(user.expenses.last.amount).to eq(2_000)
    end

    context "when product already exists" do
      let(:duplicate_params) do
        {
          brand: "londa",
          name: "SHAMPOO",
          category: "shampoo",
          purchase_price: 250,
          sale_price: 400,
          stock_quantity: 10,
          purchased_on: Date.current.iso8601
        }
      end

      before { create(:care_product, user: user, brand: "Londa", name: "Shampoo", category: "Shampoo") }

      it "does not create duplicate care product" do
        expect { post care_products_path, params: { care_product: duplicate_params } }.not_to change(CareProduct, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "does not create expense or opening balance" do
        expect { post care_products_path, params: { care_product: duplicate_params } }.not_to change(user.expenses, :count)
        expect(user.care_product_stock_movements.count).to eq(0)
      end
    end
  end

  describe "PATCH /care_products/:id" do
    it "updates care product" do
      care_product.update!(name: "Old Name")

      patch care_product_path(care_product), params: { care_product: { name: "New Name" } }

      expect(response).to redirect_to(care_products_path(locale: I18n.locale))
      expect(care_product.reload.name).to eq("New Name")
    end

    it "renders edit when invalid" do
      patch care_product_path(care_product), params: { care_product: { name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not update stock quantity or purchase price directly" do
      care_product.update!(purchase_price: 800, stock_quantity: 60)

      patch care_product_path(care_product), params: { care_product: { purchase_price: 900, stock_quantity: 100 } }

      care_product.reload

      expect(care_product.purchase_price).to eq(800)
      expect(care_product.stock_quantity).to eq(60)
    end
  end

  describe "GET /care_products/:id/restock" do
    it "returns success" do
      get restock_care_product_path(care_product)

      expect(response).to have_http_status(:ok)
    end

    it "does not allow access to another user's product" do
      other_product = create(:care_product)

      get restock_care_product_path(other_product)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /care_products/:id/restock" do
    let(:care_product) { create(:care_product, user: user, purchase_price: 800, stock_quantity: 60) }
    let(:restock_params) { { restock: { quantity: 10, unit_cost: 850, purchased_on: Date.current.iso8601 } } }

    it "increases stock" do
      expect { post restock_care_product_path(care_product), params: restock_params }
        .to change { care_product.reload.stock_quantity }.from(60).to(70)
    end

    it "creates expense" do
      expect { post restock_care_product_path(care_product), params: restock_params }.to change { user.expenses.count }.by(1)
    end

    it "creates stock movement" do
      expect { post restock_care_product_path(care_product), params: restock_params }
      .to change { user.care_product_stock_movements.count }.by(1)
    end

    it "redirects to care products" do
      post restock_care_product_path(care_product), params: restock_params

      expect(response).to redirect_to(care_products_path(locale: I18n.locale))
    end

    it "does not allow restocking another user's product" do
      other_product = create(:care_product)

      expect { post restock_care_product_path(other_product), params: restock_params }.not_to change(CareProductStockMovement, :count)

      expect(response).to have_http_status(:not_found)
    end

    context "with invalid quantity" do
      before { restock_params[:restock][:quantity] = 0 }

      it "returns unprocessable content" do
        post restock_care_product_path(care_product), params: restock_params

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "does not change stock" do
        expect { post restock_care_product_path(care_product), params: restock_params }.not_to change { care_product.reload.stock_quantity }
      end

      it "does not create expense" do
        expect { post restock_care_product_path(care_product), params: restock_params }.not_to change { user.expenses.count }
      end

      it "does not create stock movement" do
        expect { post restock_care_product_path(care_product), params: restock_params }
          .not_to change { user.care_product_stock_movements.count }
      end
    end
  end

  describe "DELETE /care_products/:id" do
    it "destroys care product" do
      care_product

      expect { delete care_product_path(care_product) }.to change(CareProduct, :count).by(-1)
      expect(response).to redirect_to(care_products_path(locale: I18n.locale))
    end
  end
end

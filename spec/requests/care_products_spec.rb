require "rails_helper"

RSpec.describe "CareProducts" do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user, :trial) }
  let(:other_user) { create(:user) }
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

    it "does not include archived or deleted products" do
      active_product =
        create(:care_product, user: user, brand: "Londa", name: "Active Shampoo", category: "Shampoo")
      archived_product =
        create(:care_product, user: user, brand: "Londa", name: "Archived Shampoo", category: "Shampoo", archived_at: Time.current)
      deleted_product =
        create(:care_product, user: user, brand: "Londa", name: "Deleted Shampoo", category: "Shampoo", deleted_at: Time.current)

      get care_products_path

      products = controller.instance_variable_get(:@care_products)

      expect(products).to include(active_product)
      expect(products).not_to include(archived_product)
      expect(products).not_to include(deleted_product)
    end
  end

  describe "GET /care_products/new" do
    it "renders page" do
      get new_care_product_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /care_products/:id" do
    it "returns success" do
      get care_product_path(care_product)

      expect(response).to have_http_status(:ok)
    end

    it "loads the care product stock movements newest first" do
      older_movement = create(:care_product_stock_movement, user: user, care_product: care_product,
                              movement_type: "purchase", quantity: 5, occurred_on: 2.days.ago.to_date)

      newer_movement = create(:care_product_stock_movement, user: user, care_product: care_product,
                              movement_type: "purchase", quantity: 10, occurred_on: Date.current)

      get care_product_path(care_product)

      movements = controller.instance_variable_get(:@stock_movements)

      expect(movements.to_a).to eq([ newer_movement, older_movement ])
    end

    it "does not include movements from another care product" do
      movement = create(:care_product_stock_movement, user: user, care_product: care_product,
                        movement_type: "purchase", quantity: 5, occurred_on: Date.current)

      other_product = create(:care_product, user: user, brand: "Wella", name: "Mask", category: "Mask")

      create(:care_product_stock_movement, user: user, care_product: other_product,
              movement_type: "purchase", quantity: 10, occurred_on: Date.current)

      get care_product_path(care_product)

      movements = controller.instance_variable_get(:@stock_movements)

      expect(movements).to contain_exactly(movement)
    end

    it "does not allow access to another user's care product" do
      other_product = create(:care_product, user: other_user)

      get care_product_path(other_product)

      expect(response).to have_http_status(:not_found)
    end

    it "allows access to archived product history" do
      care_product.update!(archived_at: Time.current)

      get care_product_path(care_product)

      expect(response).to have_http_status(:ok)
    end

    it "allows access to deleted product history" do
      care_product.update!(deleted_at: Time.current)

      get care_product_path(care_product)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /care_products/archived" do
    it "returns success" do
      get archived_care_products_path

      expect(response).to have_http_status(:ok)
    end

    it "includes only current user's archived products" do
      create(:care_product, user: user, brand: "Londa", name: "Active Shampoo", category: "Shampoo")
      archived_product =
        create(:care_product, user: user, brand: "Londa", name: "Archived Shampoo", category: "Shampoo", archived_at: Time.current)
      create(:care_product, user: user, brand: "Londa", name: "Deleted Shampoo", category: "Shampoo",
        archived_at: 1.day.ago, deleted_at: Time.current)
      create(:care_product, brand: "Londa", name: "Other User Shampoo", category: "Shampoo", archived_at: Time.current)

      get archived_care_products_path

      products = controller.instance_variable_get(:@care_products)

      expect(products).to contain_exactly(archived_product)
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

    it "does not allow access to archived product" do
      care_product.update!(archived_at: Time.current)

      get restock_care_product_path(care_product)

      expect(response).to have_http_status(:not_found)
    end

    it "does not allow access to deleted product" do
      care_product.update!(deleted_at: Time.current)

      get restock_care_product_path(care_product)

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

    it "does not allow restocking archived product" do
      care_product.update!(archived_at: Time.current)

      expect { post restock_care_product_path(care_product), params: restock_params }
        .not_to change(CareProductStockMovement, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "does not allow restocking deleted product" do
      care_product.update!(deleted_at: Time.current)

      expect { post restock_care_product_path(care_product), params: restock_params }
        .not_to change(CareProductStockMovement, :count)

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

  describe "GET /care_products/options" do
    it "returns only active care products" do
      active_product = create(:care_product, user: user, brand: "Londa", name: "Active Shampoo", category: "Shampoo")
      create(:care_product, user: user, brand: "Londa", name: "Archived Shampoo", category: "Shampoo", archived_at: Time.current)
      create(:care_product, user: user, brand: "Londa", name: "Deleted Shampoo", category: "Shampoo", deleted_at: Time.current)

      get options_care_products_path

      ids = response.parsed_body.map { |product| product["id"] }

      expect(ids).to contain_exactly(active_product.id)
    end

    it "does not return another user's care products" do
      active_product = create(:care_product, user: user, brand: "Londa", name: "Active Shampoo", category: "Shampoo")
      create(:care_product, brand: "Londa", name: "Other Shampoo", category: "Shampoo")

      get options_care_products_path

      ids = response.parsed_body.map { |product| product["id"] }

      expect(ids).to contain_exactly(active_product.id)
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
        { brand: "londa", name: "SHAMPOO", category: "shampoo",
          purchase_price: 250, sale_price: 400, stock_quantity: 10, purchased_on: Date.current.iso8601 }
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

    context "when the same product is archived" do
      let!(:archived_product) do
        create(:care_product, user: user, brand: "Londa", name: "Visible Repair",
                category: "Shampoo", stock_quantity: 0, archived_at: Time.current)
      end

      it "renders the form with archived duplicate" do
        expect {
          post care_products_path, params: {
            care_product: { brand: "Londa", name: "Visible Repair", category: "Shampoo", sale_price: 100, stock_quantity: 0 }
          }
        }.not_to change(CareProduct, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(controller.instance_variable_get(:@archived_duplicate)).to eq(archived_product)
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

  describe "PATCH /care_products/:id/archive" do
    let(:care_product) { create(:care_product, user: user, stock_quantity: 0) }

    it "archives care product" do
      expect { patch archive_care_product_path(care_product) }
        .to change { care_product.reload.archived_at }
        .from(nil)
    end

    it "redirects to care products" do
      patch archive_care_product_path(care_product)

      expect(response).to redirect_to(care_products_path(locale: I18n.locale))
    end

    it "does not archive product with remaining stock" do
      care_product.update!(stock_quantity: 5)

      expect { patch archive_care_product_path(care_product) }
        .not_to change { care_product.reload.archived_at }

      expect(response).to redirect_to(care_product_path(care_product, locale: I18n.locale))
    end

    it "does not allow archiving another user's product" do
      other_product = create(:care_product, stock_quantity: 0)

      patch archive_care_product_path(other_product)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /care_products/:id/restore" do
    let(:care_product) { create(:care_product, user: user, stock_quantity: 0, archived_at: 1.day.ago) }

    it "restores care product" do
      expect { patch restore_care_product_path(care_product) }
        .to change { care_product.reload.archived_at }
        .to(nil)
    end

    it "redirects to care product" do
      patch restore_care_product_path(care_product)

      expect(response).to redirect_to(care_product_path(care_product, locale: I18n.locale))
    end

    it "does not allow restoring another user's product" do
      other_product = create(:care_product, stock_quantity: 0, archived_at: 1.day.ago)

      patch restore_care_product_path(other_product)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /care_products/:id" do
    let(:care_product) { create(:care_product, user: user, stock_quantity: 0) }

    it "soft deletes care product" do
      expect { delete care_product_path(care_product) }.to change { care_product.reload.deleted_at }.from(nil)
      expect(care_product).to be_deleted
    end

    it "does not destroy care product record" do
      care_product

      expect { delete care_product_path(care_product) }.not_to change(CareProduct, :count)

      expect(CareProduct.exists?(care_product.id)).to be(true)
    end

    it "preserves stock movements and sales" do
      movement = create(:care_product_stock_movement, user: user, care_product: care_product,
                        movement_type: "sale", quantity: -1, stock_after: 0)

      sale = create(:care_product_sale, user: user, care_product: care_product, stock_movement: movement)

      delete care_product_path(care_product)

      expect(CareProductStockMovement.exists?(movement.id)).to be(true)
      expect(CareProductSale.exists?(sale.id)).to be(true)
      expect(sale.reload.care_product_id).to eq(care_product.id)
    end

    it "redirects to care products" do
      delete care_product_path(care_product)

      expect(response).to redirect_to(care_products_path(locale: I18n.locale))
    end

    it "removes archived state when deleting archived product" do
      care_product.update!(archived_at: 1.day.ago)

      delete care_product_path(care_product)

      expect(care_product.reload.deleted_at).to be_present
      expect(care_product.archived_at).to be_nil
    end

    it "does not delete product with remaining stock" do
      care_product.update!(stock_quantity: 5)

      expect { delete care_product_path(care_product) }.not_to change { care_product.reload.deleted_at }
      expect(response).to redirect_to(care_product_path(care_product, locale: I18n.locale))
    end

    it "does not allow deleting another user's product" do
      other_product = create(:care_product, stock_quantity: 0)

      delete care_product_path(other_product)

      expect(response).to have_http_status(:not_found)
      expect(other_product.reload.deleted_at).to be_nil
    end
  end
end

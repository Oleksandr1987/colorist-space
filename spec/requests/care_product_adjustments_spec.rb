require "rails_helper"

RSpec.describe "Care product adjustments" do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }
  let(:care_product) { create(:care_product, user: user, purchase_price: 60, stock_quantity: 10) }

  before do
    sign_in user
  end

  describe "GET /care_products/:id/adjust_stock" do
    it "returns success" do
      get adjust_stock_care_product_path(care_product)

      expect(response).to have_http_status(:ok)
    end

    it "does not allow access to another user's product" do
      other_product = create(:care_product)

      get adjust_stock_care_product_path(other_product)

      expect(response).to have_http_status(:not_found)
    end

    it "does not allow access to archived product" do
      care_product.update!(archived_at: Time.current)

      get adjust_stock_care_product_path(care_product)

      expect(response).to have_http_status(:not_found)
    end

    it "does not allow access to deleted product" do
      care_product.update!(deleted_at: Time.current)

      get adjust_stock_care_product_path(care_product)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /care_products/:id/adjust_stock" do
    let(:params) do
      { adjustment: { quantity: -3, reason: "inventory", note: "Inventory correction", occurred_on: Date.current } }
    end

    it "changes stock" do
      expect {
        patch adjust_stock_care_product_path(care_product), params: params
      }.to change { care_product.reload.stock_quantity }.from(10).to(7)
    end

    it "creates adjustment movement" do
      expect {
        patch adjust_stock_care_product_path(care_product), params: params
      }.to change(CareProductStockMovement, :count).by(1)

      movement = CareProductStockMovement.last

      expect(movement.care_product).to eq(care_product)
      expect(movement.movement_type).to eq("adjustment")
      expect(movement.adjustment_reason).to eq("inventory")
      expect(movement.quantity).to eq(-3)
      expect(movement.unit_cost).to eq(60)
      expect(movement.note).to eq("Inventory correction")
      expect(movement.occurred_on).to eq(Date.current)
    end

    it "redirects to care products" do
      patch adjust_stock_care_product_path(care_product), params: params

      expect(response).to redirect_to(care_products_path(locale: I18n.locale))
    end

    it "does not allow adjustment of another user's product" do
      other_product = create(:care_product)

      patch adjust_stock_care_product_path(other_product), params: params

      expect(response).to have_http_status(:not_found)
    end

    it "does not allow adjusting archived product" do
      care_product.update!(archived_at: Time.current)

      expect {
        patch adjust_stock_care_product_path(care_product), params: params
      }.not_to change(CareProductStockMovement, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "does not allow adjusting deleted product" do
      care_product.update!(deleted_at: Time.current)

      expect {
        patch adjust_stock_care_product_path(care_product), params: params
      }.not_to change(CareProductStockMovement, :count)

      expect(response).to have_http_status(:not_found)
    end

    context "when quantity is positive" do
      before do
        params[:adjustment][:quantity] = 5
      end

      it "increases stock" do
        expect {
          patch adjust_stock_care_product_path(care_product), params: params
        }.to change { care_product.reload.stock_quantity }.from(10).to(15)
      end
    end

    context "when stock would become negative" do
      before do
        params[:adjustment][:quantity] = -11
      end

      it "does not change stock" do
        expect {
          patch adjust_stock_care_product_path(care_product), params: params
        }.not_to change { care_product.reload.stock_quantity }
      end

      it "does not create movement" do
        expect {
          patch adjust_stock_care_product_path(care_product), params: params
        }.not_to change(CareProductStockMovement, :count)
      end

      it "returns unprocessable content" do
        patch adjust_stock_care_product_path(care_product), params: params

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when reason is invalid" do
      before do
        params[:adjustment][:reason] = "unknown"
      end

      it "returns unprocessable content" do
        patch adjust_stock_care_product_path(care_product), params: params

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when date is in the future" do
      before do
        params[:adjustment][:occurred_on] = Date.tomorrow
      end

      it "returns unprocessable content" do
        patch adjust_stock_care_product_path(care_product), params: params

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end

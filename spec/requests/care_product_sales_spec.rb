# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CareProductSales" do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }
  let(:care_product) { create(:care_product, user: user, purchase_price: 60, sale_price: 100, stock_quantity: 10) }

  before do
    sign_in user
  end

  describe "GET /care_products/:care_product_id/sales/new" do
    it "returns a successful response" do
      get new_care_product_sale_path(care_product)

      expect(response).to have_http_status(:ok)
    end

    it "does not allow access to another user's product" do
      other_product = create(:care_product)

      get new_care_product_sale_path(other_product)

      expect(response).to have_http_status(:not_found)
    end

    it "does not allow access to archived product" do
      care_product.update!(archived_at: Time.current)

      get new_care_product_sale_path(care_product)

      expect(response).to have_http_status(:not_found)
    end

    it "does not allow access to deleted product" do
      care_product.update!(deleted_at: Time.current)

      get new_care_product_sale_path(care_product)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /care_products/:care_product_id/sales" do
    let(:params) do
      { care_product_sale: { quantity: 2, unit_price: 120, sold_on: Date.current } }
    end

    it "creates a direct sale" do
      expect {
        post care_product_sales_path(care_product), params: params
      }.to change(CareProductSale, :count).by(1)
    end

    it "creates sale without a service note" do
      post care_product_sales_path(care_product), params: params

      expect(CareProductSale.last.service_note).to be_nil
    end

    it "stores sale data" do
      post care_product_sales_path(care_product), params: params

      sale = CareProductSale.last

      expect(sale.care_product).to eq(care_product)
      expect(sale.quantity).to eq(2)
      expect(sale.unit_price).to eq(120)
      expect(sale.unit_cost).to eq(60)
      expect(sale.sold_on).to eq(Date.current)
    end

    it "decreases stock" do
      expect {
        post care_product_sales_path(care_product), params: params
      }.to change { care_product.reload.stock_quantity }.from(10).to(8)
    end

    it "creates sale stock movement" do
      expect {
        post care_product_sales_path(care_product), params: params
      }.to change {
        user.care_product_stock_movements.where(movement_type: "sale").count
      }.by(1)
    end

    it "redirects to care products" do
      post care_product_sales_path(care_product), params: params

      expect(response).to redirect_to(care_products_path(locale: I18n.locale))
    end

    it "does not sell archived product" do
      care_product.update!(archived_at: Time.current)

      expect { post care_product_sales_path(care_product), params: params }.not_to change(CareProductSale, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "does not sell deleted product" do
      care_product.update!(deleted_at: Time.current)

      expect { post care_product_sales_path(care_product), params: params }.not_to change(CareProductSale, :count)
      expect(response).to have_http_status(:not_found)
    end

    context "when sold on is in the future" do
      let(:params) do
        { care_product_sale: { quantity: 2, unit_price: 120, sold_on: Date.tomorrow } }
      end

      it "does not create a sale" do
        expect {
          post care_product_sales_path(care_product), params: params
        }.not_to change(CareProductSale, :count)
      end

      it "does not change stock" do
        expect {
          post care_product_sales_path(care_product), params: params
        }.not_to change { care_product.reload.stock_quantity }
      end

      it "returns unprocessable content" do
        post care_product_sales_path(care_product), params: params

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when stock is insufficient" do
      let(:params) do
        { care_product_sale: { quantity: 11, unit_price: 120, sold_on: Date.current } }
      end

      it "does not create a sale" do
        expect { post care_product_sales_path(care_product), params: params }.not_to change(CareProductSale, :count)
      end

      it "does not change stock" do
        expect { post care_product_sales_path(care_product), params: params }.not_to change { care_product.reload.stock_quantity }
      end

      it "returns unprocessable content" do
        post care_product_sales_path(care_product), params: params

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with invalid quantity" do
      let(:params) do
        { care_product_sale: { quantity: 0, unit_price: 120, sold_on: Date.current } }
      end

      it "does not create a sale" do
        expect { post care_product_sales_path(care_product), params: params }.not_to change(CareProductSale, :count)
      end

      it "returns unprocessable content" do
        post care_product_sales_path(care_product), params: params

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with another user's product" do
      let(:other_product) { create(:care_product) }

      it "does not create a sale" do
        expect { post care_product_sales_path(other_product), params: params }.not_to change(CareProductSale, :count)
      end

      it "returns not found" do
        post care_product_sales_path(other_product), params: params

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end

require "rails_helper"

RSpec.describe CareProducts::Sell do
  subject(:sell) { described_class.new(user: user, care_product: care_product, quantity: quantity,
                                       unit_price: unit_price, sold_on: sold_on, service_note: service_note) }

  let(:user) { create(:user) }
  let(:care_product) { create(:care_product, user: user, purchase_price: 800, sale_price: 950, stock_quantity: 10) }
  let(:quantity) { 2 }
  let(:unit_price) { 950 }
  let(:sold_on) { Date.current }
  let(:service_note) { nil }

  describe "#call" do
    it "creates sale" do
      expect { sell.call }.to change(user.care_product_sales, :count).by(1)
    end

    it "returns created sale" do
      result = sell.call

      expect(result).to be_a(CareProductSale)
      expect(result).to be_persisted
    end

    it "stores sale data" do
      sale = sell.call

      expect(sale.care_product).to eq(care_product)
      expect(sale.quantity).to eq(2)
      expect(sale.unit_price).to eq(950)
      expect(sale.sold_on).to eq(Date.current)
    end

    it "snapshots current weighted average cost" do
      sale = sell.call

      expect(sale.unit_cost).to eq(800)
    end

    it "decreases stock" do
      expect { sell.call }.to change { care_product.reload.stock_quantity }.from(10).to(8)
    end

    it "creates sale stock movement" do
      expect { sell.call }.to change(user.care_product_stock_movements, :count).by(1)

      movement = user.care_product_stock_movements.last

      expect(movement.movement_type).to eq("sale")
      expect(movement.quantity).to eq(-2)
      expect(movement.unit_cost).to eq(800)
      expect(movement.occurred_on).to eq(Date.current)
    end

    it "links sale to stock movement" do
      sale = sell.call

      expect(sale.stock_movement).to be_present
      expect(sale.stock_movement.care_product).to eq(care_product)
    end

    it "calculates revenue, cost and profit from snapshots" do
      sale = sell.call

      expect(sale.revenue).to eq(1_900)
      expect(sale.cost).to eq(1_600)
      expect(sale.profit).to eq(300)
    end

    context "with service note" do
      let(:client) { create(:client, user: user) }
      let(:appointment) { create(:appointment, user: user, client: client) }
      let(:service_note) { create(:service_note, user: user, client: client, appointment: appointment) }

      it "links sale and stock movement to service note" do
        sale = sell.call

        expect(sale.service_note).to eq(service_note)
        expect(sale.stock_movement.service_note).to eq(service_note)
      end
    end

    context "when selling all remaining stock" do
      let(:quantity) { 10 }

      it "allows stock to reach zero" do
        expect { sell.call }.to change { care_product.reload.stock_quantity }.from(10).to(0)
      end
    end

    context "when quantity exceeds stock" do
      let(:quantity) { 11 }

      it "raises an error" do
        expect { sell.call }.to raise_error(ArgumentError, I18n.t("care_products.errors.not_enough_stock"))
      end

      it "does not create sale" do
        expect { sell.call rescue nil }.not_to change(CareProductSale, :count)
      end

      it "does not create stock movement" do
        expect { sell.call rescue nil }.not_to change(CareProductStockMovement, :count)
      end

      it "does not change stock" do
        expect { sell.call rescue nil }.not_to change { care_product.reload.stock_quantity }
      end
    end

    context "when quantity is zero" do
      let(:quantity) { 0 }

      it "raises an error" do
        expect { sell.call }.to raise_error(ArgumentError, I18n.t("care_products.errors.quantity_must_be_positive"))
      end
    end

    context "when quantity is negative" do
      let(:quantity) { -1 }

      it "raises an error" do
        expect { sell.call }.to raise_error(ArgumentError, I18n.t("care_products.errors.quantity_must_be_positive"))
      end
    end

    context "when unit price is negative" do
      let(:unit_price) { -1 }

      it "raises an error" do
        expect { sell.call }.to raise_error(ArgumentError, I18n.t("care_products.errors.unit_price_must_be_non_negative"))
      end
    end

    context "without sold on" do
      let(:sold_on) { nil }

      it "raises an error" do
        expect { sell.call }.to raise_error(ArgumentError, I18n.t("care_products.errors.sold_on_required"))
      end
    end

    context "when care product belongs to another user" do
      let(:care_product) { create(:care_product, purchase_price: 800, stock_quantity: 10) }

      it "raises an error" do
        expect { sell.call }.to raise_error(ArgumentError, I18n.t("care_products.errors.wrong_user"))
      end

      it "does not change stock" do
        expect { sell.call rescue nil }.not_to change { care_product.reload.stock_quantity }
      end
    end

    context "when service note belongs to another user" do
      let(:other_user) { create(:user) }
      let(:other_client) { create(:client, user: other_user) }
      let(:other_appointment) { create(:appointment, user: other_user, client: other_client) }
      let(:service_note) { create(:service_note, user: other_user, client: other_client, appointment: other_appointment) }

      it "raises an error" do
        expect { sell.call }.to raise_error(ArgumentError, I18n.t("care_products.errors.wrong_service_note_user"))
      end
    end

    context "when sale creation fails" do
      before do
        allow(user.care_product_sales).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
      end

      it "rolls back stock changes" do
        expect { sell.call rescue nil }.not_to change { care_product.reload.stock_quantity }
      end

      it "does not create stock movement" do
        expect { sell.call rescue nil }.not_to change(CareProductStockMovement, :count)
      end
    end

    context "when stock movement creation fails" do
      before do
        allow(user.care_product_stock_movements).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
      end

      it "rolls back sale" do
        expect { sell.call rescue nil }.not_to change(CareProductSale, :count)
      end

      it "does not change stock" do
        expect { sell.call rescue nil }.not_to change { care_product.reload.stock_quantity }
      end
    end

    context "when stock update fails" do
      before do
        allow(care_product).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
      end

      it "rolls back sale" do
        expect { sell.call rescue nil }.not_to change(CareProductSale, :count)
      end

      it "rolls back stock movement" do
        expect { sell.call rescue nil }.not_to change(CareProductStockMovement, :count)
      end
    end
  end
end

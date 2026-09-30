require "rails_helper"

RSpec.describe CareProducts::AdjustStock do
  subject(:adjust) do
    described_class.new(
      user: user,
      care_product: care_product,
      quantity: quantity,
      reason: reason,
      note: note,
      occurred_on: occurred_on
    )
  end

  let(:user) { create(:user) }
  let(:care_product) { create(:care_product, user: user, purchase_price: 60, stock_quantity: 10) }
  let(:quantity) { 3 }
  let(:reason) { "inventory" }
  let(:note) { "Inventory correction" }
  let(:occurred_on) { Date.current }

  describe "#call" do
    it "creates an adjustment movement" do
      expect { adjust.call }.to change(user.care_product_stock_movements, :count).by(1)

      movement = user.care_product_stock_movements.last

      expect(movement.movement_type).to eq("adjustment")
      expect(movement.adjustment_reason).to eq("inventory")
      expect(movement.quantity).to eq(3)
      expect(movement.unit_cost).to eq(60)
      expect(movement.note).to eq("Inventory correction")
      expect(movement.occurred_on).to eq(Date.current)
    end

    it "increases stock and stores stock after adjustment" do
      movement = adjust.call

      expect(care_product.reload.stock_quantity).to eq(13)
      expect(movement.stock_after).to eq(13)
      expect(movement.stock_after).to eq(care_product.stock_quantity)
    end

    context "when quantity is negative" do
      let(:quantity) { -3 }

      it "decreases stock and stores stock after adjustment" do
        movement = adjust.call

        expect(care_product.reload.stock_quantity).to eq(7)
        expect(movement.stock_after).to eq(7)
        expect(movement.stock_after).to eq(care_product.stock_quantity)
      end

      it "stores negative movement quantity" do
        adjust.call

        expect(user.care_product_stock_movements.last.quantity).to eq(-3)
      end
    end

    context "when quantity reduces stock to zero" do
      let(:quantity) { -10 }

      it "allows the adjustment" do
        expect { adjust.call }.to change { care_product.reload.stock_quantity }.from(10).to(0)
      end
    end

    context "when quantity would make stock negative" do
      let(:quantity) { -11 }

      it "raises an error" do
        expect { adjust.call }.to raise_error(ArgumentError, I18n.t("care_products.errors.adjustment_negative_stock"))
      end

      it "does not create a movement" do
        expect { adjust.call rescue nil }.not_to change(CareProductStockMovement, :count)
      end

      it "does not change stock" do
        expect { adjust.call rescue nil }.not_to change { care_product.reload.stock_quantity }
      end
    end

    context "when quantity is zero" do
      let(:quantity) { 0 }

      it "raises an error" do
        expect { adjust.call }.to raise_error(ArgumentError, I18n.t("care_products.errors.adjustment_quantity_required"))
      end
    end

    context "when reason is invalid" do
      let(:reason) { "unknown" }

      it "raises an error" do
        expect { adjust.call }.to raise_error(ArgumentError, I18n.t("care_products.errors.adjustment_reason_required"))
      end
    end

    context "when date is missing" do
      let(:occurred_on) { nil }

      it "raises an error" do
        expect { adjust.call }.to raise_error(ArgumentError, I18n.t("care_products.errors.adjustment_date_required"))
      end
    end

    context "when date is in the future" do
      let(:occurred_on) { Date.tomorrow }

      it "raises an error" do
        expect { adjust.call }.to raise_error(ArgumentError, I18n.t("care_products.errors.adjustment_date_future"))
      end
    end

    context "when care product belongs to another user" do
      let(:care_product) { create(:care_product) }

      it "raises an error" do
        expect { adjust.call }.to raise_error(ArgumentError, I18n.t("care_products.errors.wrong_user"))
      end
    end

    context "without note" do
      let(:note) { nil }

      it "creates the adjustment" do
        expect { adjust.call }.to change(CareProductStockMovement, :count).by(1)
      end
    end

    context "when stock update fails" do
      before do
        allow(care_product).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
      end

      it "rolls back movement creation" do
        expect { adjust.call rescue nil }.not_to change(CareProductStockMovement, :count)
      end

      it "does not change stock" do
        expect { adjust.call rescue nil }.not_to change { care_product.reload.stock_quantity }
      end
    end
  end
end

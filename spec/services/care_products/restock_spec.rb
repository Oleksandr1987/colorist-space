require "rails_helper"

RSpec.describe CareProducts::Restock do
  subject(:restock) do
    described_class.new(user: user, care_product: care_product, quantity: quantity, unit_cost: unit_cost, purchased_on: purchased_on)
  end

  let(:user) { create(:user) }
  let(:care_product) { create(:care_product, user: user, purchase_price: 800, stock_quantity: 60) }
  let(:quantity) { 10 }
  let(:unit_cost) { 850 }
  let(:purchased_on) { Date.current }

  describe "#call" do
    it "increases stock quantity" do
      expect { restock.call }.to change { care_product.reload.stock_quantity }.from(60).to(70)
    end

    it "calculates weighted average purchase price" do
      restock.call

      expect(care_product.reload.purchase_price).to eq(807.14)
    end

    it "creates a care product expense" do
      expect { restock.call }.to change { user.expenses.count }.by(1)

      expense = user.expenses.last

      expect(expense.category).to eq("care_products")
      expect(expense.amount).to eq(8_500)
      expect(expense.spent_on).to eq(purchased_on)
    end

    it "creates a purchase stock movement" do
      expect { restock.call }.to change { user.care_product_stock_movements.count }.by(1)

      movement = user.care_product_stock_movements.last

      expect(movement.care_product).to eq(care_product)
      expect(movement.movement_type).to eq("purchase")
      expect(movement.quantity).to eq(10)
      expect(movement.unit_cost).to eq(850)
      expect(movement.occurred_on).to eq(purchased_on)
    end

    it "links the stock movement to the expense" do
      movement = restock.call

      expect(movement.expense).to be_present
      expect(movement.expense.category).to eq("care_products")
      expect(movement.expense.amount).to eq(8_500)
    end

    context "when stock is zero" do
      let(:care_product) { create(:care_product, user: user, purchase_price: 800, stock_quantity: 0) }

      it "uses the new unit cost as purchase price" do
        restock.call

        expect(care_product.reload.purchase_price).to eq(850)
        expect(care_product.stock_quantity).to eq(10)
      end
    end

    context "when care product has no purchase price" do
      let(:care_product) { create(:care_product, user: user, purchase_price: nil, stock_quantity: 0) }

      it "uses the new unit cost as purchase price" do
        restock.call

        expect(care_product.reload.purchase_price).to eq(850)
      end
    end

    context "when quantity is invalid" do
      let(:quantity) { 0 }

      it "raises an error" do
        expect { restock.call }.to raise_error(ArgumentError, I18n.t("care_products.errors.quantity_must_be_positive"))
      end

      it "does not change stock" do
        expect { restock.call rescue nil }.not_to change { care_product.reload.stock_quantity }
      end

      it "does not create an expense" do
        expect { restock.call rescue nil }.not_to change { user.expenses.count }
      end

      it "does not create a stock movement" do
        expect { restock.call rescue nil }.not_to change { user.care_product_stock_movements.count }
      end
    end

    context "when unit cost is invalid" do
      let(:unit_cost) { -1 }

      it "raises an error" do
        expect { restock.call }.to raise_error(ArgumentError, I18n.t("care_products.errors.unit_cost_must_be_non_negative"))
      end
    end

    context "when purchased on is missing" do
      let(:purchased_on) { nil }

      it "raises an error" do
        expect { restock.call }.to raise_error(ArgumentError, I18n.t("care_products.errors.purchased_on_required"))
      end
    end

    context "when care product belongs to another user" do
      let(:other_user) { create(:user) }
      let(:care_product) { create(:care_product, user: other_user, purchase_price: 800, stock_quantity: 60) }

      it "raises an error" do
        expect { restock.call }.to raise_error(ArgumentError, I18n.t("care_products.errors.wrong_user"))
      end

      it "does not change the other user's stock" do
        expect { restock.call rescue nil }.not_to change { care_product.reload.stock_quantity }
      end
    end

    context "when stock movement cannot be created" do
      before do
        allow(user.care_product_stock_movements).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
      end

      it "rolls back the expense" do
        expect { restock.call rescue nil }.not_to change { user.expenses.count }
      end

      it "does not change stock quantity" do
        expect { restock.call rescue nil }.not_to change { care_product.reload.stock_quantity }
      end

      it "does not change purchase price" do
        expect { restock.call rescue nil }.not_to change { care_product.reload.purchase_price }
      end
    end

    context "when unit cost contains cents" do
      let(:unit_cost) { 850.50 }

      it "raises an error" do
        expect { restock.call }.to raise_error(ArgumentError, I18n.t("care_products.errors.unit_cost_must_be_whole_number"))
      end

      it "does not create an expense" do
        expect { restock.call rescue nil }.not_to change { user.expenses.count }
      end

      it "does not change stock" do
        expect { restock.call rescue nil }.not_to change { care_product.reload.stock_quantity }
      end
    end

    context "when purchased on is in the future" do
      let(:purchased_on) { Date.tomorrow }

      it "raises an error" do
        expect { restock.call }.to raise_error(ArgumentError, I18n.t("care_products.errors.purchased_on_future"))
      end

      it "does not create an expense" do
        expect { restock.call rescue nil }.not_to change { user.expenses.count }
      end
    end
  end
end

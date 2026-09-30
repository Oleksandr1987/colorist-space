require "rails_helper"

RSpec.describe CareProducts::Create do
  subject(:create_product) do
    described_class.new(user: user, attributes: attributes, purchased_on: purchased_on)
  end

  let(:user) { create(:user) }
  let(:purchased_on) { Date.current }

  let(:attributes)  { { brand: "L'Oréal", name: "Mask", category: "Mask", purchase_price: 800, sale_price: 950, stock_quantity: 10 } }

  describe "#call" do
    it "creates care product" do
      expect { create_product.call }.to change { user.care_products.count }.by(1)
    end

    it "creates opening balance movement" do
      expect { create_product.call }.to change { user.care_product_stock_movements.count }.by(1)

      movement = user.care_product_stock_movements.last

      expect(movement.movement_type).to eq("opening_balance")
      expect(movement.quantity).to eq(10)
      expect(movement.unit_cost).to eq(800)
      expect(movement.occurred_on).to eq(purchased_on)
    end

    it "creates care product expense" do
      expect { create_product.call }.to change { user.expenses.count }.by(1)

      expense = user.expenses.last

      expect(expense.category).to eq("care_products")
      expect(expense.amount).to eq(8_000)
      expect(expense.spent_on).to eq(purchased_on)
    end

    it "links opening balance to expense" do
      create_product.call

      movement = user.care_product_stock_movements.last

      expect(movement.expense).to eq(user.expenses.last)
    end

    context "without purchase price" do
      before do
        attributes[:purchase_price] = nil
      end

      it "creates opening balance" do
        expect { create_product.call }.to change { user.care_product_stock_movements.count }.by(1)
      end

      it "does not create expense" do
        expect { create_product.call }.not_to change { user.expenses.count }
      end
    end

    context "with zero stock" do
      before do
        attributes[:stock_quantity] = 0
      end

      it "does not create opening balance" do
        expect { create_product.call }.not_to change { user.care_product_stock_movements.count }
      end

      it "does not create expense" do
        expect { create_product.call }.not_to change { user.expenses.count }
      end
    end
  end
end

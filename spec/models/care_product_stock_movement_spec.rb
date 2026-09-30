require "rails_helper"

RSpec.describe CareProductStockMovement do
  subject(:movement) { build(:care_product_stock_movement) }

  let(:user) { create(:user) }
  let(:care_product) { create(:care_product, user: user, stock_quantity: 10) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:care_product) }
  it { is_expected.to belong_to(:service_note).optional }
  it { is_expected.to belong_to(:expense).optional }

  it do
    expect(movement).to validate_inclusion_of(:movement_type)
      .in_array(%w[opening_balance purchase sale adjustment])
  end

  it do
    expect(movement).to validate_numericality_of(:quantity)
      .only_integer
      .is_other_than(0)
  end

  it do
    expect(movement).to validate_numericality_of(:unit_cost)
      .is_greater_than_or_equal_to(0)
      .allow_nil
  end

  it { is_expected.to validate_presence_of(:occurred_on) }

  describe "purchase quantity" do
    it "allows positive quantity" do
      movement = build(:care_product_stock_movement, :purchase, quantity: 10)

      expect(movement).to be_valid
    end

    it "does not allow negative quantity" do
      movement = build(:care_product_stock_movement, :purchase, quantity: -10)

      expect(movement).not_to be_valid
      expect(movement.errors[:quantity]).to include("must be positive for purchase")
    end
  end

  describe "sale quantity" do
    it "allows negative quantity" do
      movement = build(:care_product_stock_movement, :sale, quantity: -2)

      expect(movement).to be_valid
    end

    it "does not allow positive quantity" do
      movement = build(:care_product_stock_movement, :sale, quantity: 2)

      expect(movement).not_to be_valid
      expect(movement.errors[:quantity]).to include("must be negative for sale")
    end
  end

  describe "adjustment quantity" do
    it "allows positive quantity" do
      movement = build(:care_product_stock_movement, :adjustment, quantity: 5, adjustment_reason: "inventory")

      expect(movement).to be_valid
    end

    it "allows negative quantity" do
      movement = build(:care_product_stock_movement, :adjustment, quantity: -5, adjustment_reason: "inventory")

      expect(movement).to be_valid
    end
  end

  describe "adjustment reason" do
    it "requires a reason for adjustment" do
      movement = build(:care_product_stock_movement, :adjustment, adjustment_reason: nil)

      expect(movement).not_to be_valid
    end

    it "allows a valid adjustment reason" do
      movement = build(:care_product_stock_movement, :adjustment, adjustment_reason: "inventory")

      expect(movement).to be_valid
    end

    it "does not allow an invalid adjustment reason" do
      movement = build(:care_product_stock_movement, :adjustment, adjustment_reason: "unknown")

      expect(movement).not_to be_valid
    end

    it "does not require a reason for purchase" do
      movement = build(:care_product_stock_movement, :purchase, adjustment_reason: nil)

      expect(movement).to be_valid
    end

    it "does not require a reason for sale" do
      movement = build(:care_product_stock_movement, :sale, adjustment_reason: nil)

      expect(movement).to be_valid
    end
  end

  describe "user ownership" do
    it "allows a care product belonging to the same user" do
      user = create(:user)
      product = create(:care_product, user: user)
      movement = build(:care_product_stock_movement, user: user, care_product: product)

      expect(movement).to be_valid
    end

    it "does not allow a care product belonging to another user" do
      user = create(:user)
      other_user = create(:user)
      product = create(:care_product, user: other_user)
      movement = build(:care_product_stock_movement, user: user, care_product: product)

      expect(movement).not_to be_valid
      expect(movement.errors[:care_product]).to include("must belong to the same user")
    end
  end

  describe "scopes" do
    it "filters purchases" do
      purchase = create(:care_product_stock_movement, :purchase)
      create(:care_product_stock_movement, :sale)
      create(:care_product_stock_movement, :adjustment)

      expect(described_class.purchases).to contain_exactly(purchase)
    end

    it "filters sales" do
      create(:care_product_stock_movement, :purchase)
      sale = create(:care_product_stock_movement, :sale)
      create(:care_product_stock_movement, :adjustment)

      expect(described_class.sales).to contain_exactly(sale)
    end

    it "filters adjustments" do
      create(:care_product_stock_movement, :purchase)
      create(:care_product_stock_movement, :sale)
      adjustment = create(:care_product_stock_movement, :adjustment)

      expect(described_class.adjustments).to contain_exactly(adjustment)
    end
  end

  describe "opening balance" do
    it "allows positive quantity" do
      movement = build(:care_product_stock_movement, movement_type: "opening_balance", quantity: 10)

      expect(movement).to be_valid
    end

    it "does not allow negative quantity" do
      movement = build(:care_product_stock_movement, movement_type: "opening_balance", quantity: -10)

      expect(movement).not_to be_valid
    end
  end

  describe "#history_type" do
    it "returns opening balance" do
      movement = build(:care_product_stock_movement, movement_type: "opening_balance")

      expect(movement.history_type).to eq("opening_balance")
    end

    it "returns purchase" do
      movement = build(:care_product_stock_movement, movement_type: "purchase")

      expect(movement.history_type).to eq("purchase")
    end

    it "returns direct sale for a sale without service note" do
      movement = create(:care_product_stock_movement, user: user, care_product: care_product,
                        movement_type: "sale", quantity: -1, unit_cost: 30, occurred_on: Date.current)

      create(:care_product_sale, user: user, care_product: care_product, stock_movement: movement,
              service_note: nil, quantity: 1, unit_price: 50, unit_cost: 30, sold_on: Date.current)

      expect(movement.reload.history_type).to eq("direct_sale")
    end

    it "returns service note sale for a sale linked to a service note" do
      service_note = create(:service_note, user: user)
      movement = create(:care_product_stock_movement, user: user, care_product: care_product,
                        service_note: service_note, movement_type: "sale", quantity: -1, unit_cost: 30, occurred_on: Date.current)

      create(:care_product_sale, user: user, care_product: care_product,
              service_note: service_note, stock_movement: movement, quantity: 1, unit_price: 50, unit_cost: 30, sold_on: Date.current)

      expect(movement.reload.history_type).to eq("service_note_sale")
    end

    it "returns the adjustment reason for an adjustment" do
      movement = build(:care_product_stock_movement, :adjustment, adjustment_reason: "damaged")

      expect(movement.history_type).to eq("damaged")
    end
  end

  describe "#total_cost" do
    it "returns unit cost multiplied by absolute quantity" do
      movement = build(:care_product_stock_movement, quantity: -3, unit_cost: 40)

      expect(movement.total_cost).to eq(120)
    end

    it "returns nil without unit cost" do
      movement = build(:care_product_stock_movement, unit_cost: nil)

      expect(movement.total_cost).to be_nil
    end
  end

  describe "#sale_total" do
    it "returns historical sale total" do
      movement = create(:care_product_stock_movement, user: user, care_product: care_product,
                        movement_type: "sale", quantity: -2, unit_cost: 30, occurred_on: Date.current)

      create(:care_product_sale, user: user, care_product: care_product,
              stock_movement: movement, quantity: 2, unit_price: 50, unit_cost: 30, sold_on: Date.current)

      expect(movement.reload.sale_total).to eq(100)
    end

    it "returns nil without a sale" do
      movement = build(:care_product_stock_movement, movement_type: "purchase")

      expect(movement.sale_total).to be_nil
    end
  end
end

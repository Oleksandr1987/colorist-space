require "rails_helper"

RSpec.describe CareProductStockMovement do
  subject(:movement) { build(:care_product_stock_movement) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:care_product) }
  it { is_expected.to belong_to(:service_note).optional }
  it { is_expected.to belong_to(:expense).optional }

  it do
    expect(movement).to validate_inclusion_of(:movement_type)
      .in_array(%w[purchase sale adjustment])
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
      movement = build(:care_product_stock_movement, :adjustment, quantity: 5)

      expect(movement).to be_valid
    end

    it "allows negative quantity" do
      movement = build(:care_product_stock_movement, :adjustment, quantity: -5)

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
end

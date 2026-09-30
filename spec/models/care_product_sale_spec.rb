require "rails_helper"

RSpec.describe CareProductSale do
  subject(:sale) { build(:care_product_sale) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:care_product) }
  it { is_expected.to belong_to(:service_note).optional }
  it { is_expected.to belong_to(:stock_movement).class_name("CareProductStockMovement").optional }

  it { is_expected.to validate_numericality_of(:quantity).only_integer.is_greater_than(0) }
  it { is_expected.to validate_numericality_of(:unit_price).is_greater_than_or_equal_to(0) }
  it { is_expected.to validate_numericality_of(:unit_cost).is_greater_than_or_equal_to(0) }
  it { is_expected.to validate_presence_of(:sold_on) }

  describe "#revenue" do
    it "returns sale revenue" do
      sale = build(:care_product_sale, quantity: 3, unit_price: 950)

      expect(sale.revenue).to eq(2_850)
    end
  end

  describe "#cost" do
    it "returns cost of goods sold" do
      sale = build(:care_product_sale, quantity: 3, unit_cost: 800)

      expect(sale.cost).to eq(2_400)
    end
  end

  describe "#profit" do
    it "returns gross profit" do
      sale = build(:care_product_sale, quantity: 3, unit_price: 950, unit_cost: 800)

      expect(sale.profit).to eq(450)
    end
  end
end

require "rails_helper"

RSpec.describe CareProduct do
  subject(:care_product) { build(:care_product) }

  it { is_expected.to belong_to(:user) }

  it { is_expected.to validate_presence_of(:name) }

  it do
    expect(care_product).to validate_numericality_of(:sale_price)
      .is_greater_than_or_equal_to(0)
      .allow_nil
  end

  it do
    expect(care_product).to validate_numericality_of(:purchase_price)
      .is_greater_than_or_equal_to(0)
      .allow_nil
  end

  it do
    expect(care_product).to validate_numericality_of(:stock_quantity)
      .is_greater_than_or_equal_to(0)
      .allow_nil
  end

  describe "#incomplete?" do
    it "returns false when all required values present" do
      expect(
        build(
          :care_product,
          purchase_price: 100,
          stock_quantity: 10
        )
      ).not_to be_incomplete
    end

    it "returns true when purchase_price is blank" do
      expect(
        build(
          :care_product,
          purchase_price: nil
        )
      ).to be_incomplete
    end

    it "returns true when stock_quantity is blank" do
      expect(
        build(
          :care_product,
          stock_quantity: nil
        )
      ).to be_incomplete
    end
  end

  describe "#display_name" do
    it "joins brand and name" do
      product = build(
        :care_product,
        brand: "Londa",
        name: "Shampoo"
      )

      expect(product.display_name)
        .to eq("Londa Shampoo")
    end
  end
end

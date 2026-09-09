require "rails_helper"

RSpec.describe FormulaProduct do
  subject(:formula_product) { build(:formula_product) }

  it { is_expected.to belong_to(:user) }

  it { is_expected.to validate_presence_of(:brand) }

  it do
    expect(formula_product).to validate_inclusion_of(:category)
      .in_array(%w[color oxidant])
  end

  it do
    expect(formula_product).to validate_inclusion_of(:unit)
      .in_array(%w[g ml])
  end

  it do
    expect(formula_product).to validate_numericality_of(:price_per_unit)
      .is_greater_than_or_equal_to(0)
  end

  describe ".colors" do
    it "returns only color category products" do
      color = create(:formula_product, category: "color")
      oxidant = create(:formula_product, :oxidant)

      expect(described_class.colors).to include(color)
      expect(described_class.colors).not_to include(oxidant)
    end
  end

  describe ".palette_list" do
    it "returns distinct color products ordered by brand" do
      wella = create(:formula_product, category: "color", brand: "Wella", name: "Koleston 7/1")
      loreal = create(:formula_product, category: "color", brand: "L'Oreal", name: "Majirel 6")
      create(:formula_product, :oxidant)

      result = described_class.palette_list

      expect(result).to eq([ loreal, wella ])
    end
  end
end

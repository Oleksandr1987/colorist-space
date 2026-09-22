require "rails_helper"

RSpec.describe FormulaProduct do
  subject(:formula_product) { build(:formula_product) }

  it { is_expected.to belong_to(:user) }

  it { is_expected.to validate_presence_of(:brand) }
  it { is_expected.to validate_presence_of(:unit) }
  it { is_expected.to validate_presence_of(:price_per_unit) }

  it do
    expect(formula_product).to validate_inclusion_of(:category).in_array(%w[color oxidant])
  end

  it do
    expect(formula_product).to validate_inclusion_of(:unit).in_array(%w[g ml])
  end

  it do
    expect(formula_product).to validate_numericality_of(:price_per_unit).is_greater_than_or_equal_to(0)
  end

  describe ".colors" do
    it "returns only color category products" do
      color = create(:formula_product, category: "color")
      oxidant = create(:formula_product, :oxidant)

      expect(described_class.colors).to include(color)
      expect(described_class.colors).not_to include(oxidant)
    end
  end

  describe ".oxidants" do
    it "returns only oxidant category products" do
      color = create(:formula_product, category: "color")
      oxidant = create(:formula_product, :oxidant)

      expect(described_class.oxidants).to include(oxidant)
      expect(described_class.oxidants).not_to include(color)
    end
  end

  describe ".ordered" do
    it "orders products by brand and name" do
      wella_9 = create(:formula_product, brand: "Wella", name: "9/0")
      matrix = create(:formula_product, brand: "Matrix", name: "7N")

      wella_7 = create(:formula_product, brand: "Wella", name: "7/0")

      expect(described_class.ordered).to eq([ matrix, wella_7, wella_9 ])
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

  describe ".brands_for" do
    it "returns unique brands for the requested category sorted alphabetically" do
      products = [
        create(:formula_product, category: "color", brand: "Wella"),
        create(:formula_product, category: "color", brand: "Matrix"),
        create(:formula_product, category: "color", brand: "Wella"),
        create(:formula_product, :oxidant, brand: "Inebrya")
      ]

      result = described_class.brands_for(products, "color")

      expect(result).to eq([ "Matrix", "Wella" ])
    end

    it "returns only oxidant brands when category is oxidant" do
      products = [
        create(:formula_product, category: "color", brand: "Wella"),
        create(:formula_product, :oxidant, brand: "Matrix"),
        create(:formula_product, :oxidant, brand: "Inebrya")
      ]

      result = described_class.brands_for(products, "oxidant")

      expect(result).to eq([ "Inebrya", "Matrix" ])
    end

    it "returns an empty array when there are no products for the category" do
      products = [ create(:formula_product, category: "color", brand: "Wella") ]

      result = described_class.brands_for(products, "oxidant")

      expect(result).to eq([])
    end
  end

  describe ".oxidant_percentages" do
    it "returns unique oxidant percentages sorted numerically" do
      products = [
        create(:formula_product, :oxidant, name: "Developer 9%"),
        create(:formula_product, :oxidant, name: "Developer 3%"),
        create(:formula_product, :oxidant, name: "Developer 12%"),
        create(:formula_product, :oxidant, name: "Another 3%")
      ]

      result = described_class.oxidant_percentages(products)

      expect(result).to eq([ "3%", "9%", "12%" ])
    end

    it "supports decimal percentages" do
      products = [
        create(:formula_product, :oxidant, name: "Developer 3%"),
        create(:formula_product, :oxidant, name: "Developer 1,5%"),
        create(:formula_product, :oxidant, name: "Developer 1.9%")
      ]

      result = described_class.oxidant_percentages(products)

      expect(result).to eq([ "1.5%", "1.9%", "3%" ])
    end

    it "ignores oxidants without a percentage" do
      products = [
        create(:formula_product, :oxidant, name: "Developer"),
        create(:formula_product, :oxidant, name: "Developer 6%")
      ]

      result = described_class.oxidant_percentages(products)

      expect(result).to eq([ "6%" ])
    end

    it "ignores percentages from color products" do
      products = [
        create(:formula_product, category: "color", name: "Color 9%"),
        create(:formula_product, :oxidant, name: "Developer 3%")
      ]

      result = described_class.oxidant_percentages(products)

      expect(result).to eq([ "3%" ])
    end
  end

  describe "#percentage" do
    context "when product is an oxidant" do
      it "extracts an integer percentage from the name" do
        product = build(:formula_product, :oxidant, name: "Developer 9%")

        expect(product.percentage).to eq("9%")
      end

      it "extracts a percentage containing a comma" do
        product = build(:formula_product, :oxidant, name: "Developer 1,5%")

        expect(product.percentage).to eq("1.5%")
      end

      it "extracts a percentage containing a decimal point" do
        product = build(:formula_product, :oxidant, name: "Developer 1.9%")

        expect(product.percentage).to eq("1.9%")
      end

      it "removes whitespace before the percent sign" do
        product = build(:formula_product, :oxidant, name: "Developer 6 %")

        expect(product.percentage).to eq("6%")
      end

      it "returns nil when the name does not contain a percentage" do
        product = build(:formula_product, :oxidant, name: "Developer")

        expect(product.percentage).to be_nil
      end

      it "deduplicates equivalent comma and dot percentages" do
        products = [
          build(:formula_product, :oxidant, name: "Developer 1,5%"),
          build(:formula_product, :oxidant, name: "Peroxide 1.5%")
        ]

        expect(described_class.oxidant_percentages(products)).to eq([ "1.5%" ])
      end
    end

    context "when product is a color" do
      it "returns nil even when the name contains a percentage" do
        product = build(:formula_product, category: "color", name: "Color 6%")

        expect(product.percentage).to be_nil
      end
    end
  end
end

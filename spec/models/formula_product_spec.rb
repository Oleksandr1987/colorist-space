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

      expect(described_class.palette_list).to eq([ loreal, wella ])
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

  describe ".oxidant_concentrations" do
    it "returns unique percentage concentrations sorted numerically" do
      products = [
        create(:formula_product, :oxidant, name: "9%"),
        create(:formula_product, :oxidant, name: "3%"),
        create(:formula_product, :oxidant, name: "12%"),
        create(:formula_product, :oxidant, name: "3%")
      ]

      result = described_class.oxidant_concentrations(products)

      expect(result).to eq([ "3%", "9%", "12%" ])
    end

    it "supports decimal percentages" do
      products = [
        create(:formula_product, :oxidant, name: "3%"),
        create(:formula_product, :oxidant, name: "1,5%"),
        create(:formula_product, :oxidant, name: "1.9%")
      ]

      result = described_class.oxidant_concentrations(products)

      expect(result).to eq([ "1.5%", "1.9%", "3%" ])
    end

    it "supports vol concentrations" do
      products = [
        create(:formula_product, :oxidant, name: "30 vol"),
        create(:formula_product, :oxidant, name: "10 vol"),
        create(:formula_product, :oxidant, name: "20 vol")
      ]

      result = described_class.oxidant_concentrations(products)

      expect(result).to eq([ "10 vol", "20 vol", "30 vol" ])
    end

    it "keeps percentages before vol concentrations" do
      products = [
        create(:formula_product, :oxidant, name: "20 vol"),
        create(:formula_product, :oxidant, name: "9%"),
        create(:formula_product, :oxidant, name: "10 vol"),
        create(:formula_product, :oxidant, name: "3%")
      ]

      result = described_class.oxidant_concentrations(products)

      expect(result).to eq([ "3%", "9%", "10 vol", "20 vol" ])
    end

    it "ignores concentrations from color products" do
      products = [
        create(:formula_product, category: "color", name: "9%"),
        create(:formula_product, :oxidant, name: "3%")
      ]

      result = described_class.oxidant_concentrations(products)

      expect(result).to eq([ "3%" ])
    end

    it "deduplicates equivalent comma and dot percentages" do
      products = [
        build(:formula_product, :oxidant, name: "1,5%"),
        build(:formula_product, :oxidant, name: "1.5%")
      ]

      expect(described_class.oxidant_concentrations(products)).to eq([ "1.5%" ])
    end
  end

  describe "#concentration" do
    context "when product is an oxidant" do
      it "returns an integer percentage" do
        product = build(:formula_product, :oxidant, name: "9%")

        expect(product.concentration).to eq("9%")
      end

      it "normalizes a percentage containing a comma" do
        product = build(:formula_product, :oxidant, name: "1,5%")

        expect(product.concentration).to eq("1.5%")
      end

      it "returns a percentage containing a decimal point" do
        product = build(:formula_product, :oxidant, name: "1.9%")

        expect(product.concentration).to eq("1.9%")
      end

      it "removes whitespace before the percent sign" do
        product = build(:formula_product, :oxidant, name: "6 %")

        expect(product.concentration).to eq("6%")
      end

      it "returns a vol concentration" do
        product = build(:formula_product, :oxidant, name: "30 vol")

        expect(product.concentration).to eq("30 vol")
      end

      it "normalizes uppercase VOL" do
        product = build(:formula_product, :oxidant, name: "20 VOL")

        expect(product.concentration).to eq("20 vol")
      end

      it "returns nil when name is not a concentration" do
        product = build(:formula_product, :oxidant, name: "Developer")

        expect(product.concentration).to be_nil
      end
    end

    context "when product is a color" do
      it "returns nil even when name looks like a concentration" do
        product = build(:formula_product, category: "color", name: "6%")

        expect(product.concentration).to be_nil
      end
    end
  end

  describe "oxidant concentration validation" do
    it "accepts percentage concentration" do
      product = build(:formula_product, :oxidant, name: "9%")

      expect(product).to be_valid
    end

    it "accepts decimal percentage concentration" do
      product = build(:formula_product, :oxidant, name: "1.9%")

      expect(product).to be_valid
    end

    it "accepts comma decimal percentage concentration" do
      product = build(:formula_product, :oxidant, name: "1,5%")

      expect(product).to be_valid
    end

    it "accepts vol concentration" do
      product = build(:formula_product, :oxidant, name: "30 vol")

      expect(product).to be_valid
    end

    it "rejects an oxidant name without a concentration" do
      product = build(:formula_product, :oxidant, name: "Developer")

      expect(product).not_to be_valid
      expect(product.errors[:name]).to be_present
    end

    it "does not apply concentration validation to colors" do
      product = build(:formula_product, category: "color", name: "Koleston 7/1")

      expect(product).to be_valid
    end
  end
end

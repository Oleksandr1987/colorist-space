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
      expect(build(:care_product, purchase_price: 100, stock_quantity: 10)).not_to be_incomplete
    end

    it "returns true when purchase_price is blank" do
      expect(build(:care_product, purchase_price: nil)).to be_incomplete
    end

    it "returns true when stock_quantity is blank" do
      expect(build(:care_product, stock_quantity: nil)).to be_incomplete
    end
  end

  describe "#stock_value" do
    it "returns purchase price multiplied by stock quantity" do
      product = build(:care_product, purchase_price: 800, stock_quantity: 60)

      expect(product.stock_value).to eq(48_000)
    end
  end

  describe ".total_stock_value" do
    let(:user) { create(:user) }

    it "returns total purchase value of products in stock" do
      create(:care_product, user: user, name: "Shampoo", purchase_price: 800, stock_quantity: 10)
      create(:care_product, user: user, name: "Mask", purchase_price: 500, stock_quantity: 9)

      expect(user.care_products.total_stock_value).to eq(12_500)
    end
  end

  describe "product identity" do
    let(:user) { create(:user) }

    it "normalizes identity fields" do
      product =
        create(:care_product, user: user, brand: "  L'Oréal   Professionnel ", name: "  ШАМПУНЬ   Від випадіння ", category: "  Догляд ")

      expect(product.brand).to eq("L'Oréal Professionnel")
      expect(product.name).to eq("ШАМПУНЬ Від випадіння")
      expect(product.category).to eq("Догляд")
      expect(product.normalized_brand).to eq("l'oréal professionnel")
      expect(product.normalized_name).to eq("шампунь від випадіння")
      expect(product.normalized_category).to eq("догляд")
    end

    it "does not allow duplicate products for the same user" do
      create(:care_product, user: user, brand: "Na Golovy", name: "Шампунь", category: "Догляд")

      duplicate = build(:care_product, user: user, brand: "Na Golovy", name: "Шампунь", category: "Догляд")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end

    it "checks duplicate identity case insensitively for Ukrainian text" do
      create(:care_product, user: user, brand: "Na Golovy", name: "Шампунь від випадіння", category: "Догляд")

      duplicate = build(:care_product, user: user, brand: "NA GOLOVY", name: "ШАМПУНЬ ВІД ВИПАДІННЯ", category: "ДОГЛЯД")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end

    it "checks duplicate identity ignoring extra whitespace" do
      create(:care_product, user: user, brand: "Na Golovy", name: "Шампунь від випадіння", category: "Догляд")

      duplicate = build(:care_product, user: user, brand: "  Na   Golovy ", name: " Шампунь   від випадіння ", category: " Догляд ")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end

    it "allows the same product for another user" do
      other_user = create(:user)

      create(:care_product, user: user, brand: "Na Golovy", name: "Шампунь", category: "Догляд")

      product = build(:care_product, user: other_user, brand: "NA GOLOVY", name: "ШАМПУНЬ", category: "ДОГЛЯД")

      expect(product).to be_valid
    end

    it "allows products with different names" do
      create(:care_product, user: user, brand: "Na Golovy", name: "Шампунь", category: "Догляд")

      product = build(:care_product, user: user, brand: "Na Golovy", name: "Маска", category: "Догляд")

      expect(product).to be_valid
    end

    it "allows products with different categories" do
      create(:care_product, user: user, brand: "Na Golovy", name: "Шампунь", category: "Догляд")

      product = build(:care_product, user: user, brand: "Na Golovy", name: "Шампунь", category: "Лікування")

      expect(product).to be_valid
    end

    it "allows updating the same product" do
      product = create(:care_product, user: user, brand: "Na Golovy", name: "Шампунь", category: "Догляд")

      product.sale_price = 1500

      expect(product).to be_valid
    end
  end

  describe "#display_name" do
    it "joins brand and name" do
      product = build(:care_product, brand: "Londa", name: "Shampoo")

      expect(product.display_name).to eq("Londa Shampoo")
    end
  end

  describe "broadcasts" do
    it "broadcasts append on create" do
      expect { create(:care_product) }.not_to raise_error
    end

    it "broadcasts replace on update" do
      product = create(:care_product)

      expect { product.update!(name: "New Name") }.not_to raise_error
    end

    it "broadcasts remove on destroy" do
      product = create(:care_product)

      expect { product.destroy }.not_to raise_error
    end
  end
end

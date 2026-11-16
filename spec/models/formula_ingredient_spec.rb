# spec/models/formula_ingredient_spec.rb

require "rails_helper"

RSpec.describe FormulaIngredient do
  describe "associations" do
    it { is_expected.to belong_to(:formula_step) }
    it { is_expected.to belong_to(:formula_product).optional }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:shade) }
    it { is_expected.to validate_presence_of(:amount) }
  end

  describe "#total_price" do
    it "returns amount multiplied by price" do
      ingredient = build(
        :formula_ingredient,
        amount: 30,
        price: 2.5
      )

      expect(ingredient.total_price).to eq(75.0)
    end

    it "returns 0 when price is nil" do
      ingredient = build(
        :formula_ingredient,
        amount: 30,
        price: nil
      )

      expect(ingredient.total_price).to eq(0.0)
    end

    it "returns 0 when amount is nil" do
      ingredient = build(
        :formula_ingredient,
        amount: nil,
        price: 5
      )

      expect(ingredient.total_price).to eq(0.0)
    end

    it "works with string values" do
      ingredient = build(
        :formula_ingredient,
        amount: "20",
        price: "3.5"
      )

      expect(ingredient.total_price).to eq(70.0)
    end
  end

  describe "#color?" do
    it "returns true when kind is color" do
      ingredient = build(:formula_ingredient, kind: "color")

      expect(ingredient.color?).to be true
    end

    it "returns false when kind is additive" do
      ingredient = build(:formula_ingredient, kind: "additive")

      expect(ingredient.color?).to be false
    end
  end

  describe "#additive?" do
    it "returns true when kind is additive" do
      ingredient = build(:formula_ingredient, kind: "additive")

      expect(ingredient.additive?).to be true
    end

    it "returns false when kind is color" do
      ingredient = build(:formula_ingredient, kind: "color")

      expect(ingredient.additive?).to be false
    end
  end

  describe "#formula_product_belongs_to_user" do
    let(:user) { create(:user) }
    let(:other_user) { create(:user) }
    let(:service_note) { build(:service_note, :without_services, user: user, appointment: nil) }
    let(:formula_step) { build(:formula_step, service_note: service_note) }

    it "allows an ingredient without a formula product" do
      ingredient = build(:formula_ingredient, formula_step: formula_step, formula_product: nil, formula_product_id: nil)

      expect(ingredient).to be_valid
      expect(ingredient.errors[:formula_product]).to be_empty
    end

    it "allows a formula product belonging to the same user" do
      product = create(:formula_product, user: user)
      ingredient = build(:formula_ingredient, formula_step: formula_step, formula_product: product)

      expect(ingredient).to be_valid
      expect(ingredient.errors[:formula_product]).to be_empty
    end

    it "rejects a formula product belonging to another user" do
      product = create(:formula_product, user: other_user)
      ingredient = build(:formula_ingredient, formula_step: formula_step, formula_product: product)

      expect(ingredient).not_to be_valid
      expect(ingredient.errors.details[:formula_product]) .to include(hash_including(error: :invalid))
    end

    it "skips ownership validation when service note has no user" do
      product = create(:formula_product, user: other_user)
      note = build(:service_note, :without_services, appointment: nil, user: nil)
      step = build(:formula_step, service_note: note)
      ingredient = build(:formula_ingredient, formula_step: step, formula_product: product)

      ingredient.valid?

      expect(ingredient.errors[:formula_product]).to be_empty
    end

    it "skips ownership validation when formula step is missing" do
      product = create(:formula_product, user: other_user)
      ingredient = build(:formula_ingredient, formula_step: nil, formula_product: product)

      ingredient.valid?

      expect(ingredient.errors[:formula_product]).to be_empty
    end

    it "skips ownership validation when service note is missing" do
      product = create(:formula_product, user: other_user)
      step = build(:formula_step, service_note: nil)
      ingredient = build(:formula_ingredient, formula_step: step, formula_product: product)

      ingredient.valid?

      expect(ingredient.errors[:formula_product]).to be_empty
    end
  end
end

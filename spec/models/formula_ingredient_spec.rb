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
end

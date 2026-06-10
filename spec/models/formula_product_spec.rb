require "rails_helper"

RSpec.describe FormulaProduct do
  subject(:formula_product) { build(:formula_product) }

  it { is_expected.to belong_to(:user) }

  it { is_expected.to validate_presence_of(:brand) }
  it { is_expected.to validate_presence_of(:name) }

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
end

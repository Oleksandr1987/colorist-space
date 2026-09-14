class FormulaIngredient < ApplicationRecord
  belongs_to :formula_step, inverse_of: :formula_ingredients
  belongs_to :formula_product, optional: true

  validates :shade, :amount, presence: true

  def total_cost
    amount.to_f * price.to_f
  end

  def total_price
    total_cost
  end
end

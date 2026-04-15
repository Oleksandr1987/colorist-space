class FormulaIngredient < ApplicationRecord
  belongs_to :formula_step, inverse_of: :formula_ingredients

  validates :shade, :amount, presence: true
end

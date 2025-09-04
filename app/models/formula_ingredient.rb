class FormulaIngredient < ApplicationRecord
  belongs_to :formula_step

  validates :shade, :amount, presence: true
end
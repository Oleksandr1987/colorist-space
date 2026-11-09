class FormulaIngredient < ApplicationRecord
  KINDS = %w[color additive].freeze

  belongs_to :formula_step, inverse_of: :formula_ingredients
  belongs_to :formula_product, optional: true

  validates :shade, :amount, presence: true
  validates :kind, inclusion: { in: KINDS }

  scope :colors, -> { where(kind: "color") }
  scope :additives, -> { where(kind: "additive") }

  def color?
    kind == "color"
  end

  def additive?
    kind == "additive"
  end

  def total_cost
    amount.to_f * price.to_f
  end

  def total_price
    total_cost
  end
end

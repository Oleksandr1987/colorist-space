class FormulaIngredient < ApplicationRecord
  KINDS = %w[color additive].freeze

  belongs_to :formula_step, inverse_of: :formula_ingredients
  belongs_to :formula_product, optional: true

  validates :shade, :amount, presence: true
  validates :kind, inclusion: { in: KINDS }

  validate :formula_product_belongs_to_user

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

  private

  def formula_product_belongs_to_user
    return if formula_product_id.blank?

    user = formula_step&.service_note&.user
    return if user.blank?

    unless user.formula_products.exists?(id: formula_product_id)
      errors.add(:formula_product, :invalid)
    end
  end
end

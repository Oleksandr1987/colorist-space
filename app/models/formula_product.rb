class FormulaProduct < ApplicationRecord
  belongs_to :user

  validates :brand, presence: true
  validates :category, inclusion: { in: %w[color oxidant] }
  validates :unit, presence: true, inclusion: { in: %w[g ml] }
  validates :price_per_unit, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :colors, -> { where(category: "color") }

  scope :oxidants, -> { where(category: "oxidant") }

  scope :palette_list, -> { colors.select(:id, :brand, :unit, :price_per_unit).distinct.order(:brand) }
end

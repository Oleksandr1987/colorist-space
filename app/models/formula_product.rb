class FormulaProduct < ApplicationRecord
  belongs_to :user

  validates :brand, presence: true
  validates :name, presence: true

  validates :category,
    inclusion: {
      in: %w[color oxidant]
    }

  validates :unit,
    inclusion: {
      in: %w[g ml]
    }

  validates :price_per_unit,
    numericality: {
      greater_than_or_equal_to: 0
    }
end

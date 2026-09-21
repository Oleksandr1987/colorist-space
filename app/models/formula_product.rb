class FormulaProduct < ApplicationRecord
  belongs_to :user

  validates :brand, presence: true
  validates :category, inclusion: { in: %w[color oxidant] }
  validates :unit, presence: true, inclusion: { in: %w[g ml] }
  validates :price_per_unit, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :colors, -> { where(category: "color") }
  scope :oxidants, -> { where(category: "oxidant") }
  scope :ordered, -> { order(:brand, :name) }

  scope :palette_list, -> { colors.select(:id, :brand, :unit, :price_per_unit).distinct.order(:brand) }

  class << self
    def brands_for(products, category)
      products
        .select { |product| product.category == category }
        .map(&:brand)
        .compact_blank
        .uniq
        .sort
    end

    def oxidant_percentages(products)
      products
        .select { |product| product.category == "oxidant" }
        .filter_map(&:percentage)
        .uniq
        .sort_by { |percentage| percentage.tr(",", ".").to_f }
    end
  end

  def percentage
    return unless category == "oxidant"

    name.to_s[/\d+(?:[.,]\d+)?\s*%/]&.delete(" ")
  end
end

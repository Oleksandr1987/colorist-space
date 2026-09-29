class FormulaProduct < ApplicationRecord
  belongs_to :user

  validates :brand, presence: true
  validates :category, inclusion: { in: %w[color oxidant] }
  validates :unit, presence: true, inclusion: { in: %w[g ml] }
  validates :price_per_unit, presence: true, numericality: { greater_than_or_equal_to: 0 }

  validates :name, presence: true, if: :oxidant?
  validate :valid_oxidant_concentration

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

    def oxidant_concentrations(products)
      products
        .select { |product| product.category == "oxidant" }
        .filter_map(&:concentration)
        .uniq
        .sort_by { |value| concentration_sort_key(value) }
    end

    private

    def concentration_sort_key(value)
      number = value.to_f
      type = value.include?("%") ? 0 : 1

      [ type, number ]
    end
  end

  def oxidant?
    category == "oxidant"
  end

  def concentration
    return unless oxidant?

    match = name.to_s.strip.match(/\A(\d+(?:[.,]\d+)?)\s*(%|vol)\z/i)

    return unless match

    value = match[1].tr(",", ".")
    type = match[2].downcase

    type == "%" ? "#{value}%" : "#{value} vol"
  end

  private

  def valid_oxidant_concentration
    return unless oxidant?
    return if name.blank?

    return if name.match?(/\A\d+(?:[.,]\d+)?\s*(?:%|vol)\z/i)

    errors.add(:name, :invalid)
  end
end

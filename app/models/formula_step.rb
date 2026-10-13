class FormulaStep < ApplicationRecord
  SECTIONS = %w[
    roots
    midshaft
    length
    strands
    all_over
  ].freeze

  belongs_to :service_note, inverse_of: :formula_steps
  has_many :formula_ingredients, dependent: :destroy, inverse_of: :formula_step

  accepts_nested_attributes_for :formula_ingredients,
    allow_destroy: true,
    reject_if: proc { |attrs| attrs["shade"].blank? && attrs["amount"].blank? }

  validates :section, presence: true, inclusion: { in: SECTIONS }
  validates :time, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_validation :normalize_values

  attribute :time, :integer, default: 0
  attribute :oxidant, :json, default: []

  def clear_oxidant!
    update!(oxidant: nil)
  end

  def clear_time!
    update!(time: 0)
  end

  def oxidant_product
    item = oxidant_data.first

    return unless item

    FormulaProduct.find_by(id: item["formula_product_id"] || item["service_id"])
  end

  def oxidant_data
    return [] if oxidant.blank?

    data =
      case oxidant
      when String
        begin
          parsed = JSON.parse(oxidant)
          parsed.is_a?(Array) ? parsed : [ parsed ]
        rescue JSON::ParserError
          []
        end
      when Array
        oxidant
      when Hash
        [ oxidant ]
      else
        []
      end

    data.select do |item|
      item["formula_product_id"].present? || item["service_id"].present?
    end
  end

  def oxidant_amount
    oxidant_data.sum { |o| o["amount"].to_f }
  end

  def oxidant_price
    oxidant_total_price
  end

  def oxidant_ratio
    oxidant_data.first&.dig("ratio")
  end

  def oxidant_total_price
    oxidant_data.sum do |o|
      o["amount"].to_f * o["price"].to_f
    end
  end

  def colors_total_price
    formula_ingredients.sum(&:total_price)
  end

  private

  def normalize_values
    if oxidant.present?
      begin
        parsed = oxidant.is_a?(String) ? JSON.parse(oxidant) : oxidant

        self.oxidant =
          case parsed
          when Array
            parsed
          when Hash
            [ parsed ]
          else
            nil
          end
      rescue JSON::ParserError, TypeError
        self.oxidant = nil
      end
    end

    self.oxidant = nil if oxidant.blank?
    self.time = 0 if time.nil?
  end
end

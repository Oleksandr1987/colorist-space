class FormulaStep < ApplicationRecord
  belongs_to :service_note, inverse_of: :formula_steps
  has_many :formula_ingredients, dependent: :destroy, inverse_of: :formula_step

  accepts_nested_attributes_for :formula_ingredients,
    allow_destroy: true,
    reject_if: proc { |attrs| attrs["shade"].blank? && attrs["amount"].blank? }

  validates :section, presence: true

  before_validation :normalize_values

  attribute :oxidant, :json, default: {}

  def clear_oxidant!
    update!(oxidant: nil)
  end

  def clear_time!
    update!(time: nil)
  end

  def oxidant_service
    id =
      oxidant["formula_product_id"] ||
      oxidant["service_id"]

    return unless id

    FormulaProduct.find_by(id: id)
  end

  def oxidant_data
    return {} if oxidant.blank?

    data =
      case oxidant
      when String
        JSON.parse(oxidant) rescue {}
      when Hash
        oxidant
      else
        {}
      end

    id = data["formula_product_id"] || data["service_id"]

    return {} unless id.present?

    data
  end

  def oxidant_amount
    oxidant_data["amount"].to_f
  end

  def oxidant_price
    oxidant_data["price"].to_f
  end

  def oxidant_ratio
    oxidant_data["ratio"]
  end

  def oxidant_total_price
    oxidant_price * oxidant_amount
  end

  def colors_total_price
    formula_ingredients.sum(&:total_price)
  end

  private

  def normalize_values
    if oxidant.present?
      begin
        parsed = oxidant.is_a?(String) ? JSON.parse(oxidant) : oxidant
        self.oxidant = parsed
      rescue
        self.oxidant = nil
      end
    end

    self.oxidant = nil if oxidant.blank?
    self.time = nil if time.blank?
  end
end

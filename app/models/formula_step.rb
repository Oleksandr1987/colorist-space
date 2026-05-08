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
    return unless oxidant["service_id"]

    Service.find_by(id: oxidant["service_id"])
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

    return {} unless data["service_id"].present?

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

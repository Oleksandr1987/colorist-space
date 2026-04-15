class FormulaStep < ApplicationRecord
  belongs_to :service_note, inverse_of: :formula_steps
  has_many :formula_ingredients, dependent: :destroy, inverse_of: :formula_step

  accepts_nested_attributes_for :formula_ingredients,
  allow_destroy: true,
  reject_if: proc { |attrs| attrs["shade"].blank? && attrs["amount"].blank? }

  validates :section, presence: true

  before_validation :normalize_values

  def clear_oxidant!
    update!(oxidant: nil)
  end

  def clear_time!
    update!(time: nil)
  end

  private

  def normalize_values
    self.oxidant = nil if oxidant.blank?
    self.time = nil if time.blank?
  end
end

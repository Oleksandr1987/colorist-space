class FormulaStep < ApplicationRecord
  belongs_to :service_note
  has_many :formula_ingredients, dependent: :destroy

  accepts_nested_attributes_for :formula_ingredients, allow_destroy: true

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

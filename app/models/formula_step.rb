class FormulaStep < ApplicationRecord
  belongs_to :service_note
  has_many :formula_ingredients, dependent: :destroy

  accepts_nested_attributes_for :formula_ingredients, allow_destroy: true

  validates :section, presence: true

  # Ensure blank values are saved as nil
  before_validation do
    self.oxidant = nil if oxidant.blank?
    self.time    = nil if time.blank?
  end
end
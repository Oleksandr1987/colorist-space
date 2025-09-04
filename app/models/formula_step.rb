class FormulaStep < ApplicationRecord
  belongs_to :service_note
  has_many :formula_ingredients, dependent: :destroy

  accepts_nested_attributes_for :formula_ingredients, allow_destroy: true

  validates :section, presence: true
end
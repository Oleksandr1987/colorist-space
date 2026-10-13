class FormulaCharge < ApplicationRecord
  KINDS = %w[color oxidant].freeze

  belongs_to :user
  belongs_to :appointment
  belongs_to :service_note, optional: true
  belongs_to :formula_product, optional: true

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :product_name, presence: true
  validates :amount,
    numericality: { greater_than_or_equal_to: 0 }

  validates :unit_price,
    numericality: { greater_than_or_equal_to: 0 }

  validates :total,
    numericality: { greater_than_or_equal_to: 0 }

  scope :for_user_between, ->(user, from, to) {
    joins(:appointment)
      .where(
        user_id: user.id,
        appointments: { appointment_date: from..to }
      )
  }

  scope :colors, -> { where(kind: "color") }
  scope :oxidants, -> { where(kind: "oxidant") }
end

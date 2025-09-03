class Service < ApplicationRecord
  belongs_to :user, optional: true

  has_many :appointment_services_relations, inverse_of: :service, dependent: :destroy
  has_many :appointments, through: :appointment_services_relations

  validates :name, presence: true
  validates :category, presence: true, if: -> { service_type == "service" }
  validates :subtype, presence: true
  validates :price, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :service_type, inclusion: { in: %w[service preparation care_product] }

  scope :income_total_for_user_between, ->(user, from_date, to_date) {
    joins(:appointments)
      .where(appointments: { user_id: user.id, appointment_date: from_date..to_date })
      .sum(:price)
  }
end

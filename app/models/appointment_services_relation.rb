class AppointmentServicesRelation < ApplicationRecord
  belongs_to :appointment, inverse_of: :appointment_services_relations
  belongs_to :service, inverse_of: :appointment_services_relations

  before_validation :snapshot_price, on: :create

  validates :appointment, :service, presence: true
  validates :price, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :service_id, uniqueness: { scope: :appointment_id }

  scope :for_user, ->(user_id) { joins(:appointment).where(appointments: { user_id: user_id }) }

  scope :for_user_between, ->(user, from, to) { joins(:appointment).where(appointments: { user_id: user.id, appointment_date: from..to }) }

  scope :ordered_for_income, -> { joins(:appointment).order("appointments.appointment_date DESC", "appointments.appointment_time DESC") }

  scope :between, ->(from, to) { joins(:appointment).where(appointments: { appointment_date: from..to }) }

  scope :for_categories, ->(categories) {
    categories = Array(categories).compact_blank

    categories.any? ? joins(:service).where(services: { category: categories }) : all
  }

  scope :for_services, ->(service_ids) {
    ids = Array(service_ids).compact_blank.map(&:to_i)

    ids.any? ? where(service_id: ids) : all
  }

  private

  def snapshot_price
    return if price.present?
    return unless service.present?

    self.price = service.price
  end
end

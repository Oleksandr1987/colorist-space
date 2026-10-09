class AppointmentServicesRelation < ApplicationRecord
  belongs_to :appointment, inverse_of: :appointment_services_relations
  belongs_to :service, inverse_of: :appointment_services_relations

  before_validation :snapshot_service, on: :create

  validates :appointment, :service, presence: true
  validates :price, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :service_id, uniqueness: { scope: :appointment_id }
  validates :service_name, :service_category, presence: true

  scope :for_user, ->(user_id) { joins(:appointment).where(appointments: { user_id: user_id }) }

  scope :for_user_between, ->(user, from, to) { joins(:appointment).where(appointments: { user_id: user.id, appointment_date: from..to }) }

  scope :ordered_for_income, -> { joins(:appointment).order("appointments.appointment_date DESC", "appointments.appointment_time DESC") }

  scope :between, ->(from, to) { joins(:appointment).where(appointments: { appointment_date: from..to }) }

  scope :for_categories, ->(categories) {
    categories = Array(categories).compact_blank

    categories.any? ? where(service_category: categories) : all
  }

  scope :for_services, ->(service_ids) {
    ids = Array(service_ids).compact_blank.map(&:to_i)

    ids.any? ? where(service_id: ids) : all
  }

  private

  def snapshot_service
    return unless service.present?

    self.price = service.price if price.blank?
    self.service_name = service.subtype
    self.service_category = service.category
  end
end

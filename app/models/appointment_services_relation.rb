class AppointmentServicesRelation < ApplicationRecord
  belongs_to :appointment, inverse_of: :appointment_services_relations
  belongs_to :service, inverse_of: :appointment_services_relations

  validates :appointment, :service, presence: true

  scope :for_user, ->(user_id) {
    joins(:appointment)
      .where(appointments: { user_id: user_id })
      .distinct
  }
end

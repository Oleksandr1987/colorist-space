class ServiceNote < ApplicationRecord
  belongs_to :user
  belongs_to :client
  belongs_to :appointment, optional: true

  has_many :service_note_services, dependent: :destroy
  has_many :services, through: :service_note_services

  has_many_attached :photos
  has_many :formula_steps, dependent: :destroy, inverse_of: :service_note

  accepts_nested_attributes_for :formula_steps, allow_destroy: true
  scope :for_client, ->(client_id) { where(client_id: client_id).order(created_at: :desc) }

  before_validation :set_price_from_services
  before_validation :copy_notes_from_appointment, on: :create

  after_save :sync_appointment_services
  after_save :sync_appointment_notes
  after_destroy :clear_appointment_services

  def short_title
    case service_type
    when "haircut" then "Стрижка"
    when "coloring" then "Фарбування"
    when "care" then "Догляд"
    else service_type.to_s.capitalize
    end
  end

  def decorated_photos
    photos.map { |p| PhotoDecorator.decorate(p) }
  end

  def service_names
    services.map(&:subtype).join(" + ")
  end

  def all_services
    return services if services.any?
    return appointment.services if appointment&.services&.any?

    Service.none
  end

  private

  def set_price_from_services
    return if price.present?
    return if services.empty?
    self.price = services.sum(&:price)
  end

  def copy_notes_from_appointment
    return if notes.present?
    return unless appointment&.notes.present?

    self.notes = appointment.notes
  end

  def sync_appointment_services
    return unless appointment.present?

    appointment.services = services

    appointment.update_column(
      :service_name,
      services.map(&:subtype).join(" + ")
    )
  end

  def sync_appointment_notes
    return unless appointment.present?

    return if appointment.notes == notes

    appointment.update_column(:notes, notes)
  end

  def clear_appointment_services
    return unless appointment.present?

    appointment.services = []
    appointment.update_column(:service_name, nil)
  end
end

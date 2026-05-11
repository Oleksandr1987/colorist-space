class ServiceNote < ApplicationRecord
  belongs_to :user
  belongs_to :client
  belongs_to :appointment

  has_many :service_note_services, dependent: :destroy
  has_many :services, through: :service_note_services

  has_many_attached :photos
  has_many :formula_steps, dependent: :destroy, inverse_of: :service_note

  accepts_nested_attributes_for :formula_steps, allow_destroy: true

  validates :appointment_id, uniqueness: true

  scope :for_client, ->(client_id) { where(client_id: client_id).order(created_at: :desc) }

  before_validation :set_price_from_services
  before_validation :copy_notes_from_appointment, on: :create

  after_save :sync_appointment_services
  after_save :sync_appointment_notes
  after_destroy :clear_appointment_services

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

  def developer_total_amount
    formula_steps.sum(&:oxidant_amount)
  end

  def developer_total_price
    formula_steps.sum(&:oxidant_total_price)
  end

  def care_products_total
    return 0 unless care_products.is_a?(Array)

    care_products.sum do |item|
      item["price"].to_f * item["qty"].to_f
    end
  end

  def final_price
    services.sum(&:price) +
      developer_total_price +
      care_products_total
  end

  def appointment_date
    appointment.appointment_date
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
    return if services.empty?

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

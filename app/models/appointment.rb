class Appointment < ApplicationRecord
  belongs_to :user
  belongs_to :client

  has_many :appointment_services_relations, inverse_of: :appointment, dependent: :destroy
  has_many :services, through: :appointment_services_relations

  validates :appointment_date, :appointment_time, presence: true
  validate :valid_date
  validate :no_time_conflicts
  validate :time_step_interval
  validate :must_have_main_service

  validates :appointment_time, uniqueness: { scope: :appointment_date, message: "is already booked for this date" }

  before_validation :set_default_end_time, if: -> { appointment_time.present? && end_time.blank? }

  scope :by_date, ->(date) { where(appointment_date: date) }

  def start_time
    "#{appointment_date}T#{appointment_time.strftime('%H:%M:%S')}"
  end

  def set_default_end_time
    self.end_time = appointment_time + 30.minutes
  end

  def total_price
    services.sum(:price)
  end

  def combined_service_name
    services.pluck(:subtype).join(" + ")
  end

  private

  def valid_date
    if appointment_date.present? && appointment_date < Date.today
      errors.add(:appointment_date, "can't be in the past")
    end
  end

  def no_time_conflicts
    return if appointment_date.blank? || appointment_time.blank? || end_time.blank?

    conflicts = Appointment.where(user_id: user_id, appointment_date: appointment_date)
      .where.not(id: id)
      .where("appointment_time < ? AND end_time > ?", end_time, appointment_time)

    if conflicts.exists?
      errors.add(:base, "This time slot is already taken by another appointment.")
    end
  end

  def time_step_interval
    [ appointment_time, end_time ].compact.each do |time|
      if time.min % 5 != 0
        errors.add(:appointment_time, "must be at 30-minute intervals")
      end
    end
  end

  def must_have_main_service
    if services.select { |s| s.service_type == "service" }.empty?
      errors.add(:base, "At least one main service must be selected")
    end
  end
end

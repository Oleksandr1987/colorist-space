class Appointment < ApplicationRecord
  belongs_to :user
  belongs_to :client

  has_many :appointment_services_relations, inverse_of: :appointment, dependent: :destroy
  has_many :services, through: :appointment_services_relations

  validates :appointment_date, :appointment_time, presence: true
  validates :appointment_time, uniqueness: { scope: :appointment_date, message: "is already booked for this date" }

  validate :valid_date
  validate :no_time_conflicts
  validate :time_step_interval
  validate :must_have_main_service

  before_validation :set_default_end_time, if: -> { appointment_time.present? && end_time.blank? }
  before_save :set_service_name

  scope :by_date, ->(date) { where(appointment_date: date) }

  scope :past, -> {
    today = Date.current
    now = Time.zone.now.strftime("%H:%M")

    where(
      arel_table[:appointment_date].lt(today)
      .or(
        arel_table[:appointment_date].eq(today).and(
          arel_table[:end_time].lt(now)
        )
      )
    )
  }

  scope :future, -> {
    today = Date.current
    now = Time.zone.now.strftime("%H:%M")

    where(
      arel_table[:appointment_date].gt(today)
      .or(
        arel_table[:appointment_date].eq(today).and(
          arel_table[:end_time].gteq(now)
          .or(arel_table[:end_time].eq(nil))
        )
      )
    )
  }

  def total_price
    services.sum(:price)
  end

  def combined_service_name
    services.map(&:subtype).join(" + ")
  end

  def as_calendar_json
    start_time = appointment_time.strftime("%H:%M")
    end_time_formatted = end_time&.strftime("%H:%M")

    {
      id: id,
      client_name: client.full_name,
      service: service_name,
      phone: client.phone,
      start: "#{appointment_date}T#{start_time}",
      end: "#{appointment_date}T#{end_time_formatted}",
      appointment_time: start_time
    }
  end

  def self.grouped_by_month(relation)
    relation.group_by { |a| a.appointment_date.strftime("%B %Y") }
            .sort_by { |month, appointments| appointments.first.appointment_date.beginning_of_month }
            .to_h
  end

  def self.available_slots(user, date)
    slot_rules = user.slot_rules.select { |rule| rule.active_on?(date) }
    slots = slot_rules.flat_map { |rule| rule.slots_for(date, 5) }

    appointments = user.appointments
      .by_date(date)
      .order(:appointment_time)
      .to_a

    available = []
    pointer = 0

    slots.each do |slot|
      slot_start = slot[:start].to_time
      slot_end = slot[:end].to_time

      while pointer < appointments.length &&
            appointments[pointer].end_time <= slot_start
        pointer += 1
      end

      conflict = false

      if pointer < appointments.length
        app = appointments[pointer]

        appointment_start = app.appointment_time.change(
          year: date.year,
          month: date.month,
          day: date.day
        )

        appointment_end = app.end_time.change(
          year: date.year,
          month: date.month,
          day: date.day
        )

        conflict = slot_start < appointment_end && slot_end > appointment_start
      end

      available << slot unless conflict
    end

    available
  end

  private

  def set_default_end_time
    self.end_time = appointment_time + 30.minutes
  end

  def set_service_name
    self.service_name = combined_service_name
  end

  def set_service_name
    selected_services = services

    if selected_services.empty? && service_ids.present?
      selected_services = Service.where(id: service_ids)
    end

    self.service_name = selected_services.map(&:subtype).join(" + ")
  end

  def valid_date
    return unless appointment_date.present? && appointment_date < Date.today
    errors.add(:appointment_date, "can't be in the past")
  end

  def no_time_conflicts
    return if appointment_date.blank? || appointment_time.blank? || end_time.blank?

    conflicts = user.appointments
      .where(appointment_date: appointment_date)
      .where.not(id: id)
      .where("appointment_time < ? AND end_time > ?", end_time, appointment_time)

    errors.add(:base, "This time slot is already taken by another appointment.") if conflicts.exists?
  end

  def time_step_interval
    [ appointment_time, end_time ].compact.each do |time|
      errors.add(:appointment_time, "must be in 5-minute intervals") unless time.min % 5 == 0
    end
  end

  def must_have_main_service
    selected_services = services

    if selected_services.empty? && service_ids.present?
      selected_services = Service.where(id: service_ids)
    end

    return if selected_services.any? { |s| s.service_type == "service" }

    errors.add(:base, "At least one main service must be selected")
  end
end

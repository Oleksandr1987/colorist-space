class Appointment < ApplicationRecord
  belongs_to :user
  belongs_to :client

  attr_accessor :client_name, :phone

  has_many :appointment_services_relations, inverse_of: :appointment, dependent: :destroy
  has_many :services, through: :appointment_services_relations
  has_one :service_note, dependent: :destroy

  validates :appointment_date, :appointment_time, presence: true

  validate :valid_date
  validate :valid_end_time
  validate :no_time_conflicts
  validate :time_step_interval

  before_validation :set_default_end_time, if: -> { appointment_time.present? && end_time.blank? }
  before_save :set_service_name
  after_update :sync_service_note_client, if: :saved_change_to_client_id?
  after_save :sync_service_note_notes

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

  scope :for_styles, -> {
    includes(service_note: [ photos_attachments: :blob ])
      .order(appointment_date: :desc, appointment_time: :desc)
  }

  scope :with_client, -> { includes(:client) }

  scope :ordered, -> { order(appointment_date: :desc, appointment_time: :desc) }

  scope :search, ->(query) {
    next all if query.blank?

    term = "%#{query.strip}%"

    left_joins(:client)
      .where(
        <<~SQL,
          clients.first_name LIKE :query
          OR clients.last_name LIKE :query
          OR clients.phone LIKE :query
          OR appointments.service_name LIKE :query
          OR appointments.notes LIKE :query
        SQL
        query: term
      )
  }

  scope :for_year, ->(year) {
    next all if year.blank?

    where(appointment_date: Date.new(year.to_i, 1, 1)..Date.new(year.to_i, 12, 31))
  }

  scope :for_month, ->(year, month) {
    next all if month.blank?

    first_day = Date.new(year.to_i, month.to_i, 1)

    where(appointment_date: first_day..first_day.end_of_month)
  }

  scope :for_categories, ->(categories) {
    categories = Array(categories).reject(&:blank?)

    next all if categories.empty?

    joins(:services).where(services: { category: categories })
  }

  scope :for_services, ->(service_ids) {
    ids = Array(service_ids).reject(&:blank?)

    next all if ids.empty?

    joins(:services).where(services: { id: ids })
  }

  class << self
    def grouped_by_month(relation)
      relation
        .group_by { |appointment| appointment.appointment_date.beginning_of_month }
        .sort_by { |month, _appointments| month }
        .reverse
        .to_h
    end

    def available_years(scope)
      scope
        .distinct
        .pluck(:appointment_date)
        .map(&:year)
        .uniq
        .sort
        .reverse
    end

    def statistics(scope, year:, month:)
      first_day_of_year = Date.new(year, 1, 1)
      last_day_of_year = Date.new(year, 12, 31)
      first_day_of_month = Date.new(year, month, 1)

      {
        total: scope.count,
        current_year: scope.where(
          appointment_date: first_day_of_year..last_day_of_year
        ).count,
        current_month: scope.where(
          appointment_date: first_day_of_month..first_day_of_month.end_of_month
        ).count
      }
    end

    def available_time_ranges(user, date)
      rules = user.slot_rules.select { |rule| rule.active_on?(date) }
      appointments = user.appointments.by_date(date).order(:appointment_time).to_a

      ranges = rules.flat_map do |rule|
        slots = rule.slots_for(date, 5)

        next [] if slots.empty?

        work_start = slots.first[:start]
        work_end = slots.last[:end]

        if date == Date.current
          work_start = [ work_start, ceil_to_five_minutes(Time.current) ].max
        end

        next [] if work_start >= work_end

        day_appointments = appointments.filter_map do |appointment|
          next if appointment.end_time.blank?

          appointment_start = appointment.appointment_time.change(
            year: date.year,
            month: date.month,
            day: date.day
          )

          appointment_end = appointment.end_time.change(
            year: date.year,
            month: date.month,
            day: date.day
          )

          next if appointment_end <= work_start
          next if appointment_start >= work_end

          {
            start: [ appointment_start, work_start ].max,
            end: [ appointment_end, work_end ].min
          }
        end

        free_ranges = []
        pointer = work_start

        day_appointments.each do |appointment|
          if appointment[:start] > pointer
            free_ranges << { start: pointer, end: appointment[:start] }
          end

          pointer = [ pointer, appointment[:end] ].max
        end

        if pointer < work_end
          free_ranges << { start: pointer, end: work_end }
        end

        free_ranges
      end

      ranges.sort_by { |range| range[:start] }
    end

    private

    def ceil_to_five_minutes(time)
      seconds = time.to_i
      step = 5.minutes.to_i

      Time.zone.at(((seconds + step - 1) / step) * step)
    end
  end

  def total_price
    services.sum(:price)
  end

  def combined_service_name
    note_services = service_note&.services.to_a

    if note_services.present?
      note_services.map(&:subtype).join(" + ")
    else
      Service.joins(:appointment_services_relations)
            .where(appointment_services_relations: { appointment_id: id })
            .pluck(:subtype)
            .join(" + ")
    end
  end

  def as_calendar_json
    start_time = appointment_time.strftime("%H:%M")
    end_time_formatted = end_time&.strftime("%H:%M")

    {
      id: id,
      client_id: client.id,
      client_name: client.full_name,
      service: combined_service_name.presence || service_name,
      service_note_id: service_note&.id,
      phone: client.phone,
      start: "#{appointment_date}T#{start_time}",
      end: "#{appointment_date}T#{end_time_formatted}",
      appointment_time: start_time
    }
  end

  def client_name
    client&.full_name
  end

  private

  def set_default_end_time
    self.end_time = appointment_time + 30.minutes
  end

  def set_service_name
    selected_services = services

    if selected_services.empty? && service_ids.present?
      selected_services = Service.where(id: service_ids)
    end

    self.service_name = selected_services.map(&:subtype).join(" + ")
  end

  def valid_date
    return unless appointment_date.present?

    if new_record? && appointment_date < Date.today
      errors.add(:appointment_date, "can't be in the past")
    end
  end

  def valid_end_time
    return if appointment_time.blank? || end_time.blank?
    if end_time <= appointment_time
      errors.add(:end_time, "must be later than start time")
    end
  end

  def no_time_conflicts
    return if appointment_date.blank? || appointment_time.blank? || end_time.blank?

    conflicts = user.appointments
      .where(appointment_date: appointment_date)
      .where.not(id: id)
      .where("appointment_time < ? AND end_time > ?", end_time, appointment_time)

    errors.add(:appointment_time, "This time slot is already taken by another appointment.") if conflicts.exists?
  end

  def time_step_interval
    [ appointment_time, end_time ].compact.each do |time|
      errors.add(:appointment_time, "must be in 5-minute intervals") unless time.min % 5 == 0
    end
  end

  def sync_service_note_client
    note = ServiceNote.find_by(appointment_id: id)
    return unless note

    note.update(client_id: client_id)
  end

  def sync_service_note_notes
    return unless service_note.present?

    return if service_note.notes == notes

    service_note.update_column(:notes, notes)
  end
end

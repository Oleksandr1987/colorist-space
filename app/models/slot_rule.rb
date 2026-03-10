class SlotRule < ApplicationRecord
  belongs_to :user

  serialize :rule, coder: JSON
  serialize :weekdays, coder: JSON

  validates :start_time, :end_time, :weekdays, presence: true
  validate :end_after_start

  before_validation :build_schedule

  STEP_MINUTES = 5

  def schedule
    return if rule.blank?
    IceCube::Schedule.from_hash(rule)
  end

  def active_on?(date)
    schedule&.occurs_on?(date)
  end

  def slots_for(date, step_minutes = STEP_MINUTES)
    return [] unless active_on?(date)

    start_at = time_on(date, start_time)
    end_at   = time_on(date, end_time)

    generate_slots(start_at, end_at, step_minutes)
  end

  private

  def build_schedule
    return if start_time.blank? || weekdays.blank?

    local_start = start_time.in_time_zone

    base_time = Time.zone.local(
      2000, 1, 1,
      local_start.hour,
      local_start.min
    )

    schedule = IceCube::Schedule.new(base_time)
    schedule.add_recurrence_rule(
      IceCube::Rule.weekly.day(*weekdays.map(&:to_sym))
    )

    self.rule = schedule.to_hash
  end

  def time_on(date, time)
    local = time.in_time_zone

    date.in_time_zone.change(
      hour: local.hour,
      min: local.min
    )
  end

  def generate_slots(start_at, end_at, step_minutes)
    slots = []
    current = start_at

    while current < end_at
      finish = [ current + step_minutes.minutes, end_at ].min

      slots << {
        start: current,
        end: finish
      }

      current = finish
    end

    slots
  end

  def end_after_start
    return if start_time.blank? || end_time.blank?

    if end_time <= start_time
      errors.add(:end_time, "must be after start time")
    end
  end
end

class SlotRule < ApplicationRecord
  belongs_to :user

  serialize :rule, coder: JSON
  serialize :weekdays, coder: JSON

  validates :start_time, :end_time, :weekdays, presence: true

  def ice_cube_schedule
    IceCube::Schedule.from_hash(rule)
  end

  def ice_cube_schedule=(schedule)
    self.rule = schedule.to_hash
  end

  def active_on?(date)
    ice_cube_schedule.occurs_on?(date)
  end

  def slots_for(date, step_minutes = 5)
    return [] unless active_on?(date)

    slots = []
    current_start = date.to_time.change(hour: start_time.hour, min: start_time.min)
    slot_end = date.to_time.change(hour: end_time.hour, min: end_time.min)

    while current_start < slot_end
      current_finish = [current_start + step_minutes.minutes, slot_end].min
      slots << { start: current_start, end: current_finish }
      current_start = current_finish
    end

    slots
  end
end

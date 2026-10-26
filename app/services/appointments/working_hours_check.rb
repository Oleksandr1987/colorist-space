# frozen_string_literal: true

module Appointments
  class WorkingHoursCheck
    def initialize(user:, date:, start_time: nil, end_time: nil)
      @user = user
      @date = date.to_date
      @start_time = start_time
      @end_time = end_time
    end

    def call
      rules = user.slot_rules.select { |rule| rule.active_on?(date) }

      return { status: "day_off" } if rules.empty?

      intervals = merge_intervals(rules)

      return { status: "ok", intervals: intervals } if start_time.blank? || end_time.blank?

      from = minutes(start_time)
      to = minutes(end_time)

      return { status: "invalid_time" } if to <= from

      covered = intervals.any? do |interval|
        from >= minutes(interval[:start]) &&
          to <= minutes(interval[:end])
      end

      {
        status: covered ? "ok" : "outside_hours",
        intervals: intervals
      }
    end

    private

    attr_reader :user, :date, :start_time, :end_time

    def minutes(value)
      time = value.is_a?(String) ? Time.zone.parse(value) : value.in_time_zone
      time.hour * 60 + time.min
    end

    def merge_intervals(rules)
      ranges = rules.map do |rule|
        [ minutes(rule.start_time), minutes(rule.end_time) ]
      end.sort_by(&:first)

      merged = ranges.each_with_object([]) do |range, result|
        if result.any? && range.first <= result.last.last
          result.last[1] = [ result.last.last, range.last ].max
        else
          result << range.dup
        end
      end

      merged.map do |from, to|
        {
          start: format_time(from),
          end: format_time(to)
        }
      end
    end

    def format_time(value)
      format("%02d:%02d", value / 60, value % 60)
    end
  end
end

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

      return { status: "invalid_time" } if intervals.nil?
      return { status: "ok", intervals: intervals } if start_time.blank? || end_time.blank?

      from = minutes(start_time)
      to = minutes(end_time)

      return { status: "invalid_time" } if from.nil? || to.nil? || to <= from

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
      time = case value
      when String
        return nil unless value.match?(/\A(?:[01]\d|2[0-3]):[0-5]\d\z/)

        Time.zone.parse(value)
      when Time, DateTime, ActiveSupport::TimeWithZone
        value.in_time_zone
      end

      return nil unless time

      time.hour * 60 + time.min
    rescue ArgumentError, TypeError
      nil
    end

    def merge_intervals(rules)
      ranges = rules.map do |rule|
        from = minutes(rule.start_time)
        to = minutes(rule.end_time)

        return nil if from.nil? || to.nil? || to <= from

        [ from, to ]
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

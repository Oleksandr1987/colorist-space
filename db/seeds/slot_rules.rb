# frozen_string_literal: true

puts "🌱 Seeding slot rules..."

user = User.find_by!(email: "demo@colorist.space")

slot_rules = [
  {
    weekdays: %w[monday tuesday wednesday thursday friday],
    start_time: "09:00",
    end_time: "18:00"
  },
  {
    weekdays: %w[saturday],
    start_time: "10:00",
    end_time: "15:00"
  }
]

slot_rules.each do |attrs|
  rule =
    user.slot_rules.find do |slot_rule|
      Array(slot_rule.weekdays).map(&:to_s).sort == attrs[:weekdays].sort
    end

  rule ||= user.slot_rules.new

  rule.assign_attributes(
    weekdays: attrs[:weekdays],
    start_time: attrs[:start_time],
    end_time: attrs[:end_time]
  )

  rule.save!
end

puts "✅ Slot rules seeded"

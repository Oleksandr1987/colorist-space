FactoryBot.define do
  factory :slot_rule do
    association :user

    start_time do
      Time.zone.parse("09:00")
    end

    end_time do
      Time.zone.parse("10:00")
    end

    weekdays { %w[monday wednesday friday] }

    rule { nil }
  end
end

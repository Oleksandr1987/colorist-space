FactoryBot.define do
  factory :appointment do
    association :user
    association :client

    appointment_date { Date.today }
    appointment_time { Time.zone.parse("10:00") }
    end_time         { Time.zone.parse("10:30") }

    transient do
      main_service { nil }
      extra_services { [] }
    end

    after(:build) do |appointment, evaluator|
      if evaluator.main_service
        appointment.services << evaluator.main_service
      end

      evaluator.extra_services.each do |svc|
        appointment.services << svc
      end
    end
  end
end

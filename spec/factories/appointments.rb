FactoryBot.define do
  factory :appointment do
    association :user
    association :client

    appointment_date { Date.current + 1.day }
    appointment_time { Time.zone.parse("10:00") }
    end_time { Time.zone.parse("10:30") }

    transient do
      main_service { create(:service) }
      extra_services { [] }
    end

    after(:build) do |appointment, evaluator|
      appointment.services << evaluator.main_service

      evaluator.extra_services.each do |svc|
        appointment.services << svc
      end
    end
  end
end

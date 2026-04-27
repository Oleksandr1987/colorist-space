FactoryBot.define do
  factory :appointment do
    association :user
    association :client

    appointment_date { Date.current + 1.day }

    sequence(:appointment_time) do |n|
      Time.zone.parse("10:00") + (n * 5).minutes
    end

    transient do
      main_service { create(:service, user: user) }
      extra_services { [] }
    end

    after(:build) do |appointment, evaluator|
      appointment.appointment_time = Time.zone.parse(appointment.appointment_time.to_s)

      appointment.end_time ||= appointment.appointment_time + 30.minutes

      appointment.services << evaluator.main_service
      evaluator.extra_services.each { |svc| appointment.services << svc }
    end
  end
end

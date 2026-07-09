FactoryBot.define do
  factory :appointment do
    association :user
    association :client

    appointment_date { Date.current + 1.day }

    sequence(:appointment_time) do |n|
      Time.zone.parse("10:00") + (n * 5).minutes
    end

    transient do
      main_service { nil }
      extra_services { [] }
    end

    after(:build) do |appointment|
      appointment.appointment_time =
        Time.zone.parse(appointment.appointment_time.to_s)

      appointment.end_time ||= appointment.appointment_time + 30.minutes
    end

    after(:create) do |appointment, evaluator|
      next if evaluator.main_service.blank? && evaluator.extra_services.blank?

      if evaluator.main_service.present?
        AppointmentServicesRelation.create!(
          appointment: appointment,
          service: evaluator.main_service
        )
      end

      evaluator.extra_services.each do |svc|
        AppointmentServicesRelation.create!(
          appointment: appointment,
          service: svc
        )
      end

      appointment.reload
    end
  end
end

FactoryBot.define do
  factory :appointment do
    association :user
    association :client

    appointment_date { Date.current + 1.day }

    # Wrap within a single day so the stored (date-less) time column never
    # crosses midnight, which would otherwise make end_time < appointment_time.
    sequence(:appointment_time) do |n|
      Time.zone.parse("08:00") + ((n * 5) % (14 * 60)).minutes
    end

    transient do
      main_service { nil }
      extra_services { [] }
    end

    after(:build) do |appointment|
      appointment.appointment_time =
        Time.zone.parse(appointment.appointment_time.to_s)

      appointment.end_time ||=
        appointment.appointment_time + 30.minutes
    end

    after(:create) do |appointment, evaluator|
      services = [
        evaluator.main_service,
        *evaluator.extra_services
      ].compact

      next if services.empty?

      services.each do |service|
        AppointmentServicesRelation.create!(
          appointment: appointment,
          service: service,
          price: service.price
        )
      end

      appointment.reload
    end
  end
end

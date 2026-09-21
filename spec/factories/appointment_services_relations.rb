FactoryBot.define do
  factory :appointment_services_relation do
    appointment
    service

    price { service.price }
  end
end

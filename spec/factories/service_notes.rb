FactoryBot.define do
  factory :service_note do
    association :appointment

    user { appointment.user }
    client { appointment.client }

    service_type { "coloring" }
    notes { "Test service note" }
    price { 100 }
  end
end

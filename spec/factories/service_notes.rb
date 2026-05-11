FactoryBot.define do
  factory :service_note do
    appointment

    user { appointment.present? ? appointment.user : association(:user) }
    client { appointment.present? ? appointment.client : association(:client) }

    service_type { "coloring" }
    notes { "Test service note" }
    price { 100 }
  end
end

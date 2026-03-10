FactoryBot.define do
  factory :service_note do
    user
    client

    service_type { "coloring" }
    notes { "Test service note" }
    price { 100 }
  end
end

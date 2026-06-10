FactoryBot.define do
  factory :service do
    association :user

    service_type { "service" }
    category { "Haircut" }
    sequence(:subtype) { |n| "Short haircut #{n}" }

    name { "#{category}: #{subtype}" }
    price { 500 }
  end
end

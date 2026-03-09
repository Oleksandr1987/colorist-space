FactoryBot.define do
  factory :service do
    association :user

    service_type { "service" }
    category { "Haircut" }
    sequence(:subtype) { |n| "Short haircut #{n}" }

    name { "#{category}: #{subtype}" }
    price { 500 }

    trait :preparation do
      service_type { "preparation" }
      category { nil }
      sequence(:subtype) { |n| "Prep #{n}" }
      name { "Preparation: #{subtype}" }
    end

    trait :care_product do
      service_type { "care_product" }
      category { nil }
      sequence(:subtype) { |n| "Care #{n}" }
      name { "Care product: #{subtype}" }
    end
  end
end

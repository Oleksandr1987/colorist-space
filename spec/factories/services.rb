FactoryBot.define do
  factory :service do
    association :user
    service_type { "service" }
    category { "Haircut" }
    subtype  { "Short haircut with clippers" }
    name     { "#{category}: #{subtype}" }
    price    { 500 }

    trait :preparation do
      service_type { "preparation" }
      category { nil } # у вас category required only if service_type == "service"
      subtype  { "Prep A" }
      name     { "Preparation: #{subtype}" }
    end

    trait :care_product do
      service_type { "care_product" }
      category { nil }
      subtype  { "Care X" }
      name     { "Care product: #{subtype}" }
    end
  end
end

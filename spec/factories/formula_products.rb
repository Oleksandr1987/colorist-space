FactoryBot.define do
  factory :formula_product do
    association :user

    category { "color" }
    brand { "Wella" }
    name { "Koleston 7/1" }
    unit { "g" }
    price_per_unit { 15 }
  end

  trait :oxidant do
    category { "oxidant" }
    brand { "Generic" }
    name { "Oxidant 6%" }
    unit { "ml" }
    price_per_unit { 5 }
  end
end

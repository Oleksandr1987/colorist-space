FactoryBot.define do
  factory :formula_charge do
    association :user
    association :appointment

    service_note { nil }
    formula_product { nil }

    kind { "color" }
    brand { "Wella" }
    product_name { "10.1" }
    amount { 10 }
    unit { "g" }
    unit_price { 5 }
    total { 50 }

    trait :oxidant do
      kind { "oxidant" }
      brand { "Wella" }
      product_name { "6%" }
      unit { "ml" }
    end
  end
end

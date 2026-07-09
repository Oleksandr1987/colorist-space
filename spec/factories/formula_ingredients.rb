FactoryBot.define do
  factory :formula_ingredient do
    formula_step
    shade { "10.1" }
    brand { "Wella" }
    amount { 30 }
    price { 2.5 }
  end
end

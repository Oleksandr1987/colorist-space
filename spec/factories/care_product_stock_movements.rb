FactoryBot.define do
  factory :care_product_stock_movement do
    association :user

    care_product { association :care_product, user: user }

    movement_type { "purchase" }
    quantity { 1 }
    unit_cost { 100 }
    occurred_on { Date.current }

    trait :purchase do
      movement_type { "purchase" }
      quantity { 10 }
    end

    trait :sale do
      movement_type { "sale" }
      quantity { -1 }
    end

    trait :adjustment do
      movement_type { "adjustment" }
      adjustment_reason { "inventory" }
      quantity { 1 }
    end
  end
end

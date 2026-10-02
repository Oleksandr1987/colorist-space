FactoryBot.define do
  factory :care_product_sale do
    association :user
    association :care_product

    quantity { 1 }
    unit_price { 950 }
    unit_cost { 800 }
    sold_on { Date.current }
  end
end

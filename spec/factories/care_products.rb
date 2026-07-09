FactoryBot.define do
  factory :care_product do
    association :user

    brand { "Londa" }
    name { "Shampoo" }
    category { "Shampoo" }

    purchase_price { 100 }
    sale_price { 200 }
    stock_quantity { 10 }
  end
end

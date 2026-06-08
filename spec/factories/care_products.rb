FactoryBot.define do
  factory :care_product do
    user { nil }
    brand { "MyString" }
    name { "MyString" }
    category { "MyString" }
    purchase_price { 1 }
    sale_price { 1 }
    stock_quantity { 1 }
  end
end

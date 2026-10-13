FactoryBot.define do
  factory :care_product_sale do
    association :user

    care_product do
      association :care_product, user: user
    end

    appointment { nil }
    service_note { nil }

    quantity { 1 }
    unit_price { 950 }
    unit_cost { 800 }
    sold_on { Date.current }
  end
end

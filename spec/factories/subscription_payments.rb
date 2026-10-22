
# frozen_string_literal: true

FactoryBot.define do
  factory :subscription_payment do
    association :subscription

    sequence(:order_reference) { |n| "WFP-ORDER-#{n}" }

    merchant_account { "test_merchant" }
    source { "purchase" }
    plan { "monthly" }
    amount_minor { 100 }
    currency { "UAH" }
    status { "pending" }

    period_start { Time.current }
    period_end { 1.month.from_now }

    trait :approved do
      status { "approved" }
      processed_at { Time.current }
    end

    trait :declined do
      status { "declined" }
      processed_at { Time.current }
    end

    trait :refunded do
      status { "refunded" }
      processed_at { Time.current }
    end

    trait :voided do
      status { "voided" }
      processed_at { Time.current }
    end

    trait :yearly do
      plan { "yearly" }
      amount_minor { 1000 }
      period_end { 1.year.from_now }
    end

    trait :regular_status do
      source { "regular_status" }
    end
  end
end

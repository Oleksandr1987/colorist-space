FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    email { Faker::Internet.unique.email }

    sequence(:phone) { |n| "+380501234#{format('%03d', n)}" }

    password { "Password123!" }
    password_confirmation { password }
    tos_agreement { true }
    plan_name { nil }
    role { nil }

    trait :trial do
      plan_name { "trial" }
      created_at { 3.days.ago }
      subscription_expires_at { nil }
    end

    trait :with_active_subscription do
      subscription_expires_at { 10.days.from_now.to_date }
    end

    trait :expired_subscription do
      subscription_expires_at { 2.days.ago.to_date }
    end

    trait :superadmin do
      role { "superadmin" }
    end
  end
end

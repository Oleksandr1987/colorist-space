FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    email { Faker::Internet.unique.email }

    sequence(:phone) { |n| "+380501234#{format('%03d', n)}" }

    password { "Password123!" }
    password_confirmation { password }
    tos_agreement { true }
    role { nil }

    trait :trial do
      created_at { 3.days.ago }
    end

    trait :with_active_subscription do
      after(:create) do |user|
        user.subscription.update!(plan: "monthly", status: "active",
          current_period_start: Time.current, current_period_end: 10.days.from_now)
      end
    end

    trait :expired_subscription do
      after(:create) do |user|
        user.subscription.update!(plan: "monthly", status: "expired",
          current_period_start: 1.month.ago, current_period_end: 2.days.ago)
      end
    end

    trait :superadmin do
      role { "superadmin" }
    end
  end
end

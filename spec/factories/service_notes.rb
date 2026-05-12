FactoryBot.define do
  factory :service_note do
    association :appointment

    user { appointment&.user || association(:user) }
    client { appointment&.client || association(:client) }

    service_type { "coloring" }
    notes { "Test service note" }

    transient do
      services_count { 1 }
    end

    after(:build) do |service_note, evaluator|
      next unless evaluator.services_count.positive?

      services = build_list(
        :service,
        evaluator.services_count,
        user: service_note.user
      )

      service_note.services << services
    end

    trait :without_services do
      transient do
        services_count { 0 }
      end
    end
  end
end

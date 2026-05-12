FactoryBot.define do
  factory :formula_step do
    association :service_note

    section { "roots" }

    oxidant { nil }
    time { nil }
  end
end

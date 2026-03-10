FactoryBot.define do
  factory :formula_step do
    service_note
    section { "roots" }
    oxidant { "6%" }
    time { 30 }
  end
end

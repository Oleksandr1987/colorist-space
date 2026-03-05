FactoryBot.define do
  factory :expense do
    association :user
    category { Expense::CATEGORIES.first }
    amount   { 1000 }
    spent_on { Date.today }
    note     { "Test expense" }
  end
end

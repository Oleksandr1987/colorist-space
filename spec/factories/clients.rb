FactoryBot.define do
  factory :client do
    association :user

    first_name { Faker::Name.first_name }
    last_name  { Faker::Name.last_name }

    sequence(:phone) { |n| "+380930000#{format('%03d', n)}" }

    hair_type       { %w[Straight Wavy Curly Coily].sample }
    hair_length     { %w[Short Medium Long].sample }
    hair_structure  { %w[Thin Medium Thick].sample }
    hair_density    { %w[Sparse Medium Dense].sample }
    scalp_condition { %w[Normal Dry Oily Sensitive].sample }

    note { Faker::Lorem.sentence }
  end
end
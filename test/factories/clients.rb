FactoryBot.define do
  factory :client do
    association :user
    first_name      { Faker::Name.first_name }
    last_name       { Faker::Name.last_name }

    # +38093XXXXXXX or +38067XXXXXXX
    sequence(:phone) do |n|
      "+3809#{rand(3..9)}#{rand(1000000..9999999 - n)}"
    end

    hair_type        { %w[Straight Wavy Curly Coily].sample }
    hair_length      { %w[Short Medium Long].sample }
    hair_structure   { %w[Thin Medium Thick].sample }
    hair_density     { %w[Sparse Medium Dense].sample }
    scalp_condition  { %w[Normal Dry Oily Sensitive].sample }
    note             { Faker::Lorem.sentence }
  end
end

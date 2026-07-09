FactoryBot.define do
  factory :client_phone do
    association :client
    user { client.user }

    sequence(:phone) do |n|
      "+38050111#{format('%04d', n)}"
    end
  end
end

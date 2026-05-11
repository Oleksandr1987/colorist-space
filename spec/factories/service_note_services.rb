FactoryBot.define do
  factory :service_note_service do
    association :service_note
    association :service
  end
end

FactoryBot.define do
  factory :haircut_step do
    association :service_note
    zone { "MyString" }
    instrument { "MyString" }
    parting { "MyString" }
    elevation { "MyString" }
    cut_type { "MyString" }
    notes { "MyText" }
  end
end

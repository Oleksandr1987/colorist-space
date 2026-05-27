FactoryBot.define do
  factory :haircut_step do
    service_note { nil }
    zone { "MyString" }
    instrument { "MyString" }
    parting { "MyString" }
    elevation { "MyString" }
    cut_type { "MyString" }
    notes { "MyText" }
  end
end

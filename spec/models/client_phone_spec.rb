require "rails_helper"

RSpec.describe ClientPhone do
  describe "associations" do
    it { is_expected.to belong_to(:client) }
  end

  describe "validations" do
    subject(:client_phone) { build(:client_phone) }

    it "validates uniqueness of phone" do
      create(:client_phone, phone: "+380501112233")

      duplicate = build(:client_phone, phone: "+380501112233")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:phone]).to be_present
    end

    it "is valid with correct phone format" do
      client_phone = build(
        :client_phone,
        phone: "+380501112233"
      )

      expect(client_phone).to be_valid
    end

    it "is invalid with incorrect phone format" do
      client_phone = build(
        :client_phone,
        phone: "12345"
      )

      expect(client_phone).not_to be_valid

      expect(client_phone.errors[:phone]).to include(
        "must start with +380 and contain 9 digits after, e.g. +380123456789"
      )
    end
  end

  describe "phone normalization" do
    it "normalizes phone before validation" do
      client_phone = build(
        :client_phone,
        phone: "0501112233"
      )

      client_phone.valid?

      expect(client_phone.phone).to eq("+380501112233")
    end

    it "does nothing when phone blank" do
      client_phone = build(
        :client_phone,
        phone: nil
      )

      client_phone.valid?

      expect(client_phone.phone).to be_nil
    end
  end
end

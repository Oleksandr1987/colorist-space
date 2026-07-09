require "rails_helper"

RSpec.describe ClientPhone do
  let(:user) { create(:user) }
  let(:client) { create(:client, user: user) }
  let(:other_client) { create(:client, user: user) }
  let(:phone_number) { "+380501112233" }

  describe "associations" do
    it { is_expected.to belong_to(:client) }
  end

  describe "validations" do
    subject(:client_phone) { build(:client_phone) }

    context "when validating uniqueness for the same user" do
      it "validates uniqueness of phone for the same user" do
        create(:client_phone, client: client, user: user, phone: phone_number)

        duplicate = build(:client_phone, client: other_client, user: user, phone: phone_number)

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:phone]).to be_present
      end
    end

    it "allows the same phone for different users" do
      other_user = create(:user)
      other_client = create(:client, user: other_user)

      create(:client_phone, client: client, user: user, phone: phone_number)

      duplicate = build(:client_phone, client: other_client, user: other_user, phone: phone_number)

      expect(duplicate).to be_valid
    end

    it "does not allow phone that already exists as primary phone of another client" do
      create(:client, user: user, phone: phone_number)

      client_with_additional_phone = create(:client, user: user, phone: "+380501112234")

      additional_phone = build(:client_phone, client: client_with_additional_phone, user: user, phone: phone_number)

      expect(additional_phone).not_to be_valid

      expect(
        additional_phone.errors[:phone]
      ).to include("already belongs to another client")
    end

    it "is valid with correct phone format" do
      client_phone = build(:client_phone, phone: phone_number)

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
      client_phone = build(:client_phone, phone: "0501112233")

      client_phone.valid?

      expect(client_phone.phone).to eq("+380501112233")
    end

    it "does nothing when phone blank" do
      client_phone = build(:client_phone, phone: nil)

      client_phone.valid?

      expect(client_phone.phone).to be_nil
    end
  end
end

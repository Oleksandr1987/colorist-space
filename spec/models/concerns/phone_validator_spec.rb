require "rails_helper"

RSpec.describe PhoneValidator do
  describe ".normalize" do
    it "returns nil when value blank" do
      expect(described_class.normalize(nil)).to be_nil
      expect(described_class.normalize("")).to be_nil
    end

    it "normalizes phone starting with 0" do
      expect(
        described_class.normalize("0982751138")
      ).to eq("+380982751138")
    end

    it "normalizes phone starting with 380" do
      expect(
        described_class.normalize("380982751138")
      ).to eq("+380982751138")
    end

    it "normalizes phone starting with 8 and length 11" do
      expect(
        described_class.normalize("80982751138")
      ).to eq("+380982751138")
    end

    it "returns digits with leading plus for unknown format" do
      expect(
        described_class.normalize("12345")
      ).to eq("+12345")
    end

    it "removes non digit symbols" do
      expect(
        described_class.normalize("+38 (098) 275-11-38")
      ).to eq("+380982751138")
    end
  end

  describe "validations" do
    subject(:model) { DummyPhoneModel.new(phone: phone) }

    context "when phone valid" do
      let(:phone) { "+380982751138" }

      it "is valid" do
        expect(model).to be_valid
      end
    end

    context "when phone blank" do
      let(:phone) { nil }

      it "is invalid" do
        expect(model).not_to be_valid
        expect(model.errors[:phone]).to be_present
      end
    end

    context "when phone invalid format" do
      let(:phone) { "12345" }

      it "adds format error" do
        expect(model).not_to be_valid

        expect(model.errors[:phone]).to include(
          "must start with +380 and contain 9 digits after, e.g. +380123456789"
        )
      end
    end
  end

  describe "#normalize_phone" do
    it "normalizes phone before validation" do
      model = DummyPhoneModel.new(
        phone: "0982751138"
      )

      model.valid?

      expect(model.phone).to eq("+380982751138")
    end

    it "does nothing when phone blank" do
      model = DummyPhoneModel.new(phone: nil)

      model.valid?

      expect(model.phone).to be_nil
    end
  end
end

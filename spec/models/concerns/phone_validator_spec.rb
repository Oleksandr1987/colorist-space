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

    it "normalizes 9-digit national phone" do
      expect(
        described_class.normalize("982751138")
      ).to eq("+380982751138")
    end

    it "normalizes formatted phone" do
      expect(
        described_class.normalize("+380 (98) 275 11 38")
      ).to eq("+380982751138")
    end

    it "returns original value for unsupported format" do
      expect(
        described_class.normalize("12345")
      ).to eq("12345")
    end

    it "does not normalize old 8-prefixed format" do
      expect(
        described_class.normalize("80982751138")
      ).to eq("80982751138")
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

    context "when phone has invalid format" do
      let(:phone) { "12345" }

      it "is invalid" do
        expect(model).not_to be_valid
        expect(model.errors[:phone]).to be_present
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

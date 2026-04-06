require "rails_helper"

RSpec.describe FormulaStep, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:service_note) }
    it { is_expected.to have_many(:formula_ingredients).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:section) }
  end

  describe "callbacks" do
    describe "before_validation normalize_values" do
      let(:formula_step) { build(:formula_step, oxidant: "", time: "") }

      it "converts blank oxidant to nil" do
        formula_step.valid?
        expect(formula_step.oxidant).to be_nil
      end

      it "converts blank time to nil" do
        formula_step.valid?
        expect(formula_step.time).to be_nil
      end
    end
  end

  describe "#clear_oxidant!" do
    let(:formula_step) { create(:formula_step, oxidant: "6%") }

    it "sets oxidant to nil" do
      formula_step.clear_oxidant!
      expect(formula_step.reload.oxidant).to be_nil
    end
  end

  describe "#clear_time!" do
    let(:formula_step) { create(:formula_step, time: 30) }

    it "sets time to nil" do
      formula_step.clear_time!
      expect(formula_step.reload.time).to be_nil
    end
  end
end

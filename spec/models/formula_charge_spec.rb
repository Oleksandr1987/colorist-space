
require "rails_helper"

RSpec.describe FormulaCharge do
  subject(:formula_charge) { build(:formula_charge) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:appointment) }
    it { is_expected.to belong_to(:service_note).optional }
    it { is_expected.to belong_to(:formula_product).optional }
  end

  describe "validations" do
    it { is_expected.to validate_inclusion_of(:kind).in_array(%w[color oxidant]) }
    it { is_expected.to validate_presence_of(:kind) }
    it { is_expected.to validate_presence_of(:product_name) }
    it { is_expected.to validate_numericality_of(:amount).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:unit_price).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:total).is_greater_than_or_equal_to(0) }

    it "allows zero amount, unit price and total" do
      formula_charge.assign_attributes(amount: 0, unit_price: 0, total: 0)

      expect(formula_charge).to be_valid
    end

    it "allows a charge without a service note" do
      formula_charge.service_note = nil

      expect(formula_charge).to be_valid
    end

    it "allows a charge without a formula product" do
      formula_charge.formula_product = nil

      expect(formula_charge).to be_valid
    end

    it "requires an appointment" do
      formula_charge.appointment = nil

      expect(formula_charge).not_to be_valid
      expect(formula_charge.errors[:appointment]).to be_present
    end

    it "requires a user" do
      formula_charge.user = nil

      expect(formula_charge).not_to be_valid
      expect(formula_charge.errors[:user]).to be_present
    end
  end

  describe "scopes" do
    let(:user) { create(:user) }
    let(:other_user) { create(:user) }
    let(:client) { create(:client, user: user) }
    let(:other_client) { create(:client, user: other_user) }
    let(:from) { Date.current - 10.days }
    let(:to) { Date.current }

    def create_appointment_for(user:, client:, date:, time:)
      create(:appointment, user: user, client: client, appointment_date: date,
        appointment_time: time, end_time: (Time.zone.parse(time) + 30.minutes).strftime("%H:%M"))
    end

    describe ".for_user_between" do
      it "returns only charges belonging to the user within the selected period" do
        current_appointment = create_appointment_for(user: user, client: client, date: Date.current, time: "10:00")
        historical_appointment = create_appointment_for(user: user, client: client, date: Date.current - 20.days, time: "11:00")
        other_appointment = create_appointment_for(user: other_user, client: other_client, date: Date.current, time: "12:00")

        matching_charge = create(:formula_charge, user: user, appointment: current_appointment)
        create(:formula_charge, user: user, appointment: historical_appointment)
        create(:formula_charge, user: other_user, appointment: other_appointment)

        expect(described_class.for_user_between(user, from, to)).to contain_exactly(matching_charge)
      end

      it "includes charges on both period boundaries" do
        from_appointment = create_appointment_for(user: user, client: client, date: from, time: "10:00")
        to_appointment = create_appointment_for(user: user, client: client, date: to, time: "11:00")

        from_charge = create(:formula_charge, user: user, appointment: from_appointment)
        to_charge = create(:formula_charge, user: user, appointment: to_appointment)

        expect(described_class.for_user_between(user, from, to)).to contain_exactly(from_charge, to_charge)
      end
    end

    describe ".colors" do
      it "returns only color charges" do
        appointment = create_appointment_for(user: user, client: client, date: Date.current, time: "10:00")

        color = create(:formula_charge, user: user, appointment: appointment, kind: "color")
        create(:formula_charge, user: user, appointment: appointment, kind: "oxidant")

        expect(described_class.colors).to contain_exactly(color)
      end
    end

    describe ".oxidants" do
      it "returns only oxidant charges" do
        appointment = create_appointment_for(user: user, client: client, date: Date.current, time: "10:00")

        create(:formula_charge, user: user, appointment: appointment, kind: "color")
        oxidant = create(:formula_charge, user: user, appointment: appointment, kind: "oxidant")

        expect(described_class.oxidants).to contain_exactly(oxidant)
      end
    end

    it "supports combining period and kind scopes" do
      appointment = create_appointment_for(user: user, client: client, date: Date.current, time: "10:00")

      color = create(:formula_charge, user: user, appointment: appointment, kind: "color")
      create(:formula_charge, user: user, appointment: appointment, kind: "oxidant")

      expect(described_class.for_user_between(user, from, to).colors).to contain_exactly(color)
    end
  end

  describe "historical snapshots" do
    let(:user) { create(:user) }
    let(:client) { create(:client, user: user) }

    let(:appointment) do
      create(:appointment, user: user, client: client, appointment_date: Date.current,
        appointment_time: "10:00", end_time: "10:30")
    end

    it "preserves historical prices after catalog price changes" do
      product = create(:formula_product, user: user, category: "color", brand: "Londa", name: "7/1", price_per_unit: 5)

      charge = create(:formula_charge, user: user, appointment: appointment, formula_product: product,
        kind: "color", brand: "Londa", product_name: "7/1", amount: 10, unit: "g", unit_price: 5, total: 50)

      product.update!(price_per_unit: 10)

      expect(charge.reload.unit_price).to eq(5)
      expect(charge.total).to eq(50)
    end

    it "preserves historical product details without a catalog association" do
      charge = create(:formula_charge, user: user, appointment: appointment, formula_product: nil,
        kind: "color", brand: "Londa", product_name: "7/1", amount: 10, unit: "g", unit_price: 5, total: 50)

      expect(charge.reload).to have_attributes(
        formula_product_id: nil, brand: "Londa", product_name: "7/1",
        amount: 10, unit: "g", unit_price: 5, total: 50
      )
    end

    it "preserves the charge when its service note reference is removed" do
      charge = create(:formula_charge, user: user, appointment: appointment, service_note: nil,
        kind: "oxidant", brand: "Inebrya", product_name: "6%", amount: 20, unit: "ml", unit_price: 2, total: 40)

      expect(charge.reload).to have_attributes(service_note_id: nil, appointment_id: appointment.id, total: 40)
    end
  end
end

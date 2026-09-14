require "rails_helper"

RSpec.describe Analytics::FinancialSummary do
  include ActiveSupport::Testing::TimeHelpers

  subject(:summary) { described_class.new(user: user, from: from, to: to) }

  let(:user) { create(:user, :trial) }
  let(:other_user) { create(:user) }
  let(:client) { create(:client, user: user) }
  let(:service) { create(:service, user: user, service_type: "service", category: "coloring", subtype: "Color", price: 200) }
  let(:from) { 1.month.ago.to_date }
  let(:to) { Date.current }

  let(:care_products) { [ { "care_product_id" => 1, "name" => "Mask", "price" => 50, "purchase_price" => 30, "qty" => 2 } ] }

  let(:appointment) do
    create(:appointment, user: user, client: client,
      appointment_date: Date.current,
      appointment_time: "10:00",
      end_time: "10:30",
      main_service: service
    )
  end

  let(:service_note) do
    note = build(:service_note, :without_services, user: user, client: client, appointment: appointment, care_products: care_products)

    note.services = [ service ]
    note.save!
    note
  end

  let(:formula_step) do
    create(:formula_step,
      service_note: service_note,
      oxidant: [ { "formula_product_id" => 1, "amount" => 20, "price" => 2 } ]
    )
  end

  before do
    travel_to Time.zone.local(2026, 1, 15)
    appointment
  end

  after { travel_back }

  describe "#service_income" do
    it "uses historical appointment service prices" do
      expect(summary.service_income).to eq(200)
    end

    it "does not recalculate income after catalog price changes" do
      service.update!(price: 900)

      expect(summary.service_income).to eq(200)
    end

    it "excludes another user's income" do
      other_client = create(:client, user: other_user)
      other_service = create(:service, user: other_user, service_type: "service", category: "haircut", subtype: "Other", price: 1_000)

      create(:appointment,
        user: other_user,
        client: other_client,
        appointment_date: Date.current,
        appointment_time: "11:00",
        end_time: "11:30",
        main_service: other_service
      )

      expect(summary.service_income).to eq(200)
    end
  end

  describe "#formula_income" do
    it "includes color and oxidant income" do
      create(:formula_ingredient, formula_step: formula_step, amount: 10, price: 5)

      expect(summary.formula_income).to eq(90)
    end
  end

  describe "#care_products_income" do
    it "uses historical sale prices" do
      service_note

      expect(summary.care_products_income).to eq(100)
    end
  end

  describe "#care_products_cost" do
    it "uses historical purchase prices" do
      service_note

      expect(summary.care_products_cost).to eq(60)
    end
  end

  describe "#manual_expenses" do
    it "includes manual expenses from the period" do
      create(:expense, user: user, amount: 40, spent_on: Date.current)
      create(:expense, user: user, amount: 10, spent_on: Date.current)

      expect(summary.manual_expenses).to eq(50)
    end

    it "excludes another user's expenses" do
      create(:expense, user: other_user, amount: 500, spent_on: Date.current)

      expect(summary.manual_expenses).to eq(0)
    end
  end

  describe "totals" do
    before do
      create(:formula_ingredient, formula_step: formula_step, amount: 10, price: 5)
      create(:expense, user: user, amount: 40, spent_on: Date.current)
    end

    it "calculates total income" do
      expect(summary.total_income).to eq(390)
    end

    it "calculates total expenses" do
      expect(summary.total_expenses).to eq(100)
    end

    it "calculates balance" do
      expect(summary.balance).to eq(290)
    end
  end
end

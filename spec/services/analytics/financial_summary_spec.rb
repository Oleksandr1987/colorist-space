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

  let(:care_product) do
      create(:care_product, user: user, brand: "Test", name: "Mask", category: "Mask",
        purchase_price: 30, sale_price: 50, stock_quantity: 10)
  end

  let(:care_products) do
    [ { "care_product_id" => care_product.id, "name" => "Mask", "price" => 50, "purchase_price" => 30, "qty" => 2 } ]
  end

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

      create(:appointment, user: other_user, client: other_client,
        appointment_date: Date.current,
        appointment_time: "11:00",
        end_time: "11:30",
        main_service: other_service
      )

      expect(summary.service_income).to eq(200)
    end
  end

  describe "#formula_income" do
    let(:color_product) { create(:formula_product, user: user, category: "color", brand: "Wella", name: "7/1", unit: "g") }

    let(:oxidant_product) { create(:formula_product, :oxidant, user: user, brand: "Wella", name: "6%", unit: "ml") }

    it "includes color and oxidant income" do
      step =
        create(:formula_step, service_note: service_note,
          oxidant: [ { "formula_product_id" => oxidant_product.id, "amount" => 20, "price" => 2 } ])

      create(:formula_ingredient, formula_step: step, formula_product: color_product, amount: 10, price: 5)

      Formulas::SyncCharges.new(service_note: service_note.reload).call

      expect(summary.formula_income).to eq(90)
    end
  end

  describe "#care_products_income" do
    it "uses historical sale prices" do
      service_note

      expect(summary.care_products_income).to eq(100)
    end

    it "includes direct care product sales" do
      create(:care_product_sale, user: user, care_product: care_product,
              service_note: nil, quantity: 2, unit_price: 70, unit_cost: 30, sold_on: Date.current)

      expect(summary.care_products_income).to eq(140)
    end

    it "excludes care product sales outside the period" do
      create(:care_product_sale, user: user, care_product: care_product,
              quantity: 2, unit_price: 70, unit_cost: 30, sold_on: 2.months.ago.to_date)

      expect(summary.care_products_income).to eq(0)
    end

    it "excludes another user's care product sales" do
      other_product = create(:care_product, user: other_user)

      create(:care_product_sale, user: other_user, care_product: other_product,
              quantity: 2, unit_price: 70, unit_cost: 30, sold_on: Date.current)

      expect(summary.care_products_income).to eq(0)
    end
  end

  describe "#care_products_cost" do
    it "uses historical purchase prices" do
      service_note

      expect(summary.care_products_cost).to eq(60)
    end

    it "includes cost from direct care product sales" do
      create(:care_product_sale, user: user, care_product: care_product,
              service_note: nil,  quantity: 2, unit_price: 70, unit_cost: 30, sold_on: Date.current)

      expect(summary.care_products_cost).to eq(60)
    end
  end

  describe "#manual_expenses" do
    it "includes manual expenses from the period" do
      create(:expense, user: user, amount: 40, spent_on: Date.current)
      create(:expense, user: user, amount: 10, spent_on: Date.current)

      expect(summary.manual_expenses).to eq(50)
    end

    it "excludes care product purchase expenses" do
      create(:expense, user: user, category: "rent", amount: 10_000, spent_on: Date.current)
      create(:expense, user: user, category: "care_products", amount: 48_000, spent_on: Date.current)

      expect(summary.manual_expenses).to eq(10_000)
    end

    it "excludes another user's expenses" do
      create(:expense, user: other_user, amount: 500, spent_on: Date.current)

      expect(summary.manual_expenses).to eq(0)
    end
  end

  describe "totals" do
    let(:color_product) { create(:formula_product, user: user, category: "color", brand: "Wella", name: "7/1", unit: "g") }
    let(:oxidant_product) { create(:formula_product, :oxidant, user: user, brand: "Wella", name: "6%", unit: "ml") }

    before do
      step = create(:formula_step, service_note: service_note,
          oxidant: [ { "formula_product_id" => oxidant_product.id, "amount" => 20, "price" => 2 } ])

      create(:formula_ingredient, formula_step: step, formula_product: color_product, amount: 10, price: 5)

      Formulas::SyncCharges.new(service_note: service_note.reload).call

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

  describe "care product purchase accounting" do
    it "uses sold care product cost instead of care product purchase expenses" do
      create(:expense, user: user, category: "rent", amount: 10_000, spent_on: Date.current)
      create(:expense, user: user, category: "care_products", amount: 48_000, spent_on: Date.current)

      service_note

      expect(summary.manual_expenses).to eq(10_000)
      expect(summary.care_products_cost).to eq(60)
      expect(summary.total_expenses).to eq(10_060)
    end
  end

  describe "historical income after service note deletion" do
    let(:formula_product) { create(:formula_product, user: user, category: "color", brand: "Wella", name: "7/1", unit: "g") }

    before do
      step = create(:formula_step, service_note: service_note)

      create(:formula_ingredient, formula_step: step, formula_product: formula_product, amount: 10, price: 5)

      Formulas::SyncCharges.new(service_note: service_note.reload).call
    end

    it "preserves total income after deleting the service note" do
      total_before = summary.total_income

      service_note.destroy!

      summary_after = described_class.new(user: user, from: from, to: to)

      expect(summary_after.total_income).to eq(total_before)
    end

    it "preserves every historical income component after deleting the service note" do
      service_income_before = summary.service_income
      formula_income_before = summary.formula_income
      care_products_income_before = summary.care_products_income

      service_note.destroy!

      summary_after = described_class.new(user: user, from: from, to: to)

      expect(summary_after.service_income).to eq(service_income_before)
      expect(summary_after.formula_income).to eq(formula_income_before)
      expect(summary_after.care_products_income).to eq(care_products_income_before)
    end
  end
end

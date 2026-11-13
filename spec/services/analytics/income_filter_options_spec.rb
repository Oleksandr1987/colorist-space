
require "rails_helper"

RSpec.describe Analytics::IncomeFilterOptions do
  subject(:options) { described_class.new(user: user, from: from, to: to).call }

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:client) { create(:client, user: user) }

  let(:from) { Date.current + 7.days }
  let(:to) { from + 2.days }

  let(:appointment) do
    create(:appointment, user: user, client: client,
      appointment_date: from, appointment_time: Time.zone.parse("10:00"), end_time: Time.zone.parse("10:30"))
  end

  let(:outside_appointment) do
    create(:appointment, user: user, client: client,
      appointment_date: to + 7.days, appointment_time: Time.zone.parse("11:00"), end_time: Time.zone.parse("11:30"))
  end

  let(:haircut) { create(:service, user: user, category: "haircut", subtype: "Cut", name: "Women's haircut") }
  let(:coloring) { create(:service, user: user, category: "coloring", subtype: "Color", name: "Hair coloring") }
  let(:color_product) { create(:formula_product, user: user, category: "color", brand: "Wella", name: "7/1") }
  let(:additive_product) { create(:formula_product, user: user, category: "additive", brand: "Londa", name: "A") }
  let(:oxidant_product) { create(:formula_product, user: user, category: "oxidant", brand: "Wella", name: "6%", unit: "ml") }
  let(:care_product) { create(:care_product, user: user, brand: "Wella", name: "Mask", category: "Mask") }

  before do
    create(:appointment_services_relation, appointment: appointment, service: haircut)
    create(:appointment_services_relation, appointment: appointment, service: coloring)
    create(:formula_charge, user: user, appointment: appointment, formula_product: color_product, kind: "color")
    create(:formula_charge, user: user, appointment: appointment, formula_product: additive_product, kind: "additive")
    create(:formula_charge, :oxidant, user: user, appointment: appointment, formula_product: oxidant_product)
    create(:care_product_sale, user: user, appointment: appointment, care_product: care_product, sold_on: from)
  end

  describe "#call" do
    it "builds service options from historical service ids" do
      expect(options[:services]).to contain_exactly(
        { id: haircut.id, category: "haircut", label: "Cut" },
        { id: coloring.id, category: "coloring", label: "Color" }
      )
    end

    it "builds color, additive and oxidant options" do
      expect(options[:formula]).to eq(
        colors: [ { id: color_product.id, brand: "Wella", label: "Wella 7/1" } ],
        additives: [ { id: additive_product.id, brand: "Londa", label: "Londa A" } ],
        oxidants: [ { id: oxidant_product.id, brand: "Wella", label: "Wella 6%" } ]
      )
    end

    it "builds care product options" do
      expect(options[:care_products]).to eq([
        { id: care_product.id, brand: "Wella", category: "Mask", label: care_product.display_name }
      ])
    end

    it "does not duplicate products used multiple times" do
      create(:formula_charge, user: user, appointment: appointment, formula_product: color_product, kind: "color")
      create(:care_product_sale, user: user, appointment: appointment, care_product: care_product, sold_on: from)

      expect(options[:formula][:colors].size).to eq(1)
      expect(options[:care_products].size).to eq(1)
    end

    it "excludes services outside the selected period" do
      outside_service = create(:service, user: user, category: "styling", subtype: "Styling")

      create(:appointment_services_relation, appointment: outside_appointment, service: outside_service)

      expect(options[:services].pluck(:id)).not_to include(outside_service.id)
    end

    it "excludes formula products outside the selected period" do
      outside_product = create(:formula_product, user: user, category: "color", brand: "Matrix", name: "5/0")

      create(:formula_charge, user: user, appointment: outside_appointment, formula_product: outside_product, kind: "color")

      expect(options[:formula][:colors].pluck(:id)).not_to include(outside_product.id)
    end

    it "excludes care product sales outside the selected period" do
      outside_product = create(:care_product, user: user, brand: "Londa", name: "Shampoo")

      create(:care_product_sale, user: user, appointment: outside_appointment,
        care_product: outside_product, sold_on: outside_appointment.appointment_date
      )

      expect(options[:care_products].pluck(:id)).not_to include(outside_product.id)
    end

    it "does not include another user's services" do
      other_service = create(:service, user: other_user, category: "haircut", subtype: "Other cut")

      expect(options[:services].pluck(:id)).not_to include(other_service.id)
    end

    it "returns empty options for a period without records" do
      empty_options = described_class.new(user: user, from: to + 30.days, to: to + 35.days).call

      expect(empty_options).to eq(
        services: [],
        formula: { colors: [], additives: [], oxidants: [] },
        care_products: []
      )
    end
  end
end

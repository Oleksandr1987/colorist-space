
require "rails_helper"

RSpec.describe Analytics::IncomeReport do
  subject(:report) { described_class.new(user: user, from: from, to: to, params: params).call }


  let(:user) { create(:user) }
  let(:from) { Date.new(2026, 1, 1) }
  let(:to) { Date.new(2026, 1, 31) }
  let(:params) { {} }
  let!(:haircut) { create(:service, user: user, category: "haircut", subtype: "Cut", name: "Women's haircut") }
  let!(:coloring) { create(:service, user: user, category: "coloring", subtype: "Color", name: "Hair coloring") }
  let(:services) { [ { id: haircut.id, category: "haircut" }, { id: coloring.id, category: "coloring" } ] }

  let(:filter_options) do
    {
      services: services,
      formula: {
        colors: [ { id: 11, brand: "Wella", label: "Wella 7/1" } ],
        additives: [ { id: 12, brand: "Londa", label: "Londa A" } ],
        oxidants: [ { id: 13, brand: "Wella", label: "Wella 6%" } ]
      },
      care_products: [ { id: 21, brand: "Wella", category: "Mask", label: "Mask" } ]
    }
  end

  let(:grouped) { { "haircut" => 100, "coloring" => 200 } }
  let(:colors) { [ { amount: 50 } ] }
  let(:additives) { [ { amount: 20 } ] }
  let(:oxidants) { [ { amount: 40 } ] }
  let(:monthly) { { "January" => [ :historical_relation ] } }
  let(:summary) { instance_double(Analytics::IncomeSummary) }

  before do
    options_service = instance_double(Analytics::IncomeFilterOptions, call: filter_options)

    allow(Analytics::IncomeFilterOptions).to receive(:new).with(user: user, from: from, to: to).and_return(options_service)
    allow(Analytics::IncomeSummary).to receive(:new).and_return(summary)
    allow(summary).to receive_messages(
      grouped_service_income: grouped,
      formula_income: 110,
      care_products_income: 100,
      formula_color_income: colors,
      additive_income: additives,
      oxidant_income: oxidants,
      care_product_income: [ { amount: 100 } ],
      total_income: 510
    )

    allow(summary).to receive(:monthly_income).with("haircut").and_return(monthly)
  end

  describe "#call" do
    it "returns itself with filter options" do
      expect(report).to be_a(described_class)
      expect(report.filter_categories).to eq(%w[haircut coloring])
      expect(report.filter_services.pluck(:id)).to contain_exactly(haircut.id, coloring.id)
      expect(report.filter_color_brands).to eq([ "Wella" ])
      expect(report.filter_additive_brands).to eq([ "Londa" ])
      expect(report.filter_oxidant_brands).to eq([ "Wella" ])
      expect(report.filter_care_brands).to eq([ "Wella" ])
      expect(report.filter_care_categories).to eq([ "Mask" ])
    end

    it "passes normalized filters to the summary" do
      params.merge!(
        income_categories: [ "haircut", "INVALID" ],
        service_ids: [ haircut.id.to_s, haircut.id.to_s, "bad" ],
        formula_product_ids: [ "11", "bad" ],
        care_product_ids: [ "21" ]
      )

      report

      expect(Analytics::IncomeSummary).to have_received(:new).with(
        user: user,
        from: from,
        to: to,
        service_categories: [ "haircut" ],
        service_ids: [ haircut.id ],
        formula_product_ids: [ 11 ],
        care_product_ids: [ 21 ]
      )
    end

    it "returns full income when group filtering is not applied" do
      expect(report.display_total_income).to eq(510.0)
      expect(report.display_formula_income).to eq(110.0)
      expect(report.income_groups).to eq([])
      expect(report.formula_kinds).to eq([])
    end

    it "returns zero when group filtering is applied with no groups" do
      params[:income_groups_applied] = "1"

      expect(report.display_total_income).to eq(0.0)
    end

    it "totals services only" do
      params.merge!(income_groups_applied: "1", income_groups: [ "services" ])

      expect(report.display_total_income).to eq(300.0)
    end

    it "totals care products only" do
      params.merge!(income_groups_applied: "1", income_groups: [ "care_products" ])

      expect(report.display_total_income).to eq(100.0)
    end

    it "totals all selected groups" do
      params.merge!(income_groups_applied: "1", income_groups: %w[services formula care_products])

      expect(report.display_total_income).to eq(510.0)
    end

    it "uses full formula income when no formula kinds are selected" do
      params.merge!(income_groups_applied: "1", income_groups: [ "formula" ])

      expect(report.display_formula_income).to eq(110.0)
      expect(report.display_total_income).to eq(110.0)
    end

    { "color" => 50.0, "additive" => 20.0, "oxidant" => 40.0 }.each do |kind, amount|
      it "totals the #{kind} formula kind" do
        params.merge!(income_groups_applied: "1", income_groups: [ "formula" ], formula_kinds: [ kind ])

        expect(report.display_formula_income).to eq(amount)
        expect(report.display_total_income).to eq(amount)
      end
    end

    it "sums multiple selected formula kinds" do
      params.merge!(income_groups_applied: "1", income_groups: [ "formula" ], formula_kinds: %w[color oxidant])

      expect(report.display_formula_income).to eq(90.0)
    end

    it "ignores invalid groups and kinds" do
      params.merge!(income_groups_applied: "1", income_groups: %w[formula invalid], formula_kinds: %w[color invalid])

      expect(report.income_groups).to eq([ "formula" ])
      expect(report.formula_kinds).to eq([ "color" ])
      expect(report.display_total_income).to eq(50.0)
    end

    it "ignores stale formula kinds when formula group is not selected" do
      params.merge!(income_groups_applied: "1", income_groups: [ "services" ], formula_kinds: [ "color" ])

      expect(report.formula_kinds).to eq([])
      expect(report.display_formula_income).to eq(110.0)
    end

    it "ignores formula kinds when group filtering is not applied" do
      params[:formula_kinds] = [ "color" ]

      expect(report.formula_kinds).to eq([])
      expect(report.display_total_income).to eq(510.0)
    end

    it "expands a valid category" do
      params[:expanded] = "haircut"

      expect(report.expanded_income_category).to eq("haircut")
      expect(report.monthly_income).to eq(monthly)
      expect(summary).to have_received(:monthly_income).with("haircut")
    end

    it "does not expand an unknown category" do
      params[:expanded] = "unknown"

      expect(report.expanded_income_category).to be_nil
      expect(report.monthly_income).to eq({})
      expect(summary).not_to have_received(:monthly_income)
    end

    it "handles missing option collections" do
      filter_options[:services] = nil
      filter_options[:formula] = {}
      filter_options[:care_products] = nil

      expect(report.filter_categories).to eq([])
      expect(report.filter_services).to be_empty
      expect(report.filter_colors).to eq([])
      expect(report.filter_additives).to eq([])
      expect(report.filter_oxidants).to eq([])
      expect(report.filter_care_categories).to eq([])
    end

    it "deduplicates and sorts brand and care category options" do
      filter_options[:formula][:colors] = [
        { id: 1, brand: "Z" },
        { id: 2, brand: "A" },
        { id: 3, brand: "Z" },
        { id: 4, brand: nil }
      ]

      filter_options[:care_products] = [
        { id: 1, brand: "Z", category: "Shampoo" },
        { id: 2, brand: "A", category: "Mask" },
        { id: 3, brand: "A", category: "Mask" },
        { id: 4, brand: nil, category: "" }
      ]

      expect(report.filter_color_brands).to eq(%w[A Z])
      expect(report.filter_care_brands).to eq(%w[A Z])
      expect(report.filter_care_categories).to eq(%w[Mask Shampoo])
    end
  end
end

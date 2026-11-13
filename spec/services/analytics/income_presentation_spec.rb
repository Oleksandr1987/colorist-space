
require "rails_helper"

RSpec.describe Analytics::IncomePresentation do
  subject(:presentation) { described_class.new(report: report, params: params, from: from, to: to, all_time: all_time) }

  let(:report) { instance_double(Analytics::IncomeReport) }
  let(:params) { {} }
  let(:from) { Date.new(2026, 1, 1) }
  let(:to) { Date.new(2026, 1, 31) }
  let(:all_time) { false }

  let(:colors) { [ { amount: 10 }, { amount: 20 } ] }
  let(:additives) { [ { amount: 5 } ] }
  let(:oxidants) { [ { amount: 25 } ] }

  before do
    allow(report).to receive_messages(
      income_groups_applied: false,
      income_groups: [],
      formula_kinds: [],
      grouped_income: { "haircut" => 100 },
      display_formula_income: 60,
      care_products_income: 30,
      formula_color_income: colors,
      additive_income: additives,
      oxidant_income: oxidants,
      category_filters: [ "haircut" ],
      service_filters: [ 1 ],
      formula_product_filters: [ 11 ],
      care_product_filters: [ 21 ],
      expanded_income_category: nil
    )
  end

  describe "visibility" do
    it "shows all income groups by default" do
      expect(presentation.show_services?).to be(true)
      expect(presentation.show_formula?).to be(true)
      expect(presentation.show_care_products?).to be(true)
      expect(presentation.has_income?).to be(true)
      expect(presentation.show_content?).to be(true)
    end

    it "shows only explicitly selected groups" do
      allow(report).to receive_messages(income_groups_applied: true, income_groups: [ "services" ])

      expect(presentation.show_services?).to be(true)
      expect(presentation.show_formula?).to be(false)
      expect(presentation.show_care_products?).to be(false)
    end

    it "hides formula and care sections when their totals are zero" do
      allow(report).to receive_messages(display_formula_income: 0, care_products_income: 0)

      expect(presentation.show_formula?).to be(false)
      expect(presentation.show_care_products?).to be(false)
    end

    it "hides content when no income or filters exist" do
      allow(report).to receive_messages(grouped_income: {}, display_formula_income: 0, care_products_income: 0)

      expect(presentation.has_income?).to be(false)
      expect(presentation.show_content?).to be(false)
    end

    it "shows content when filters exist despite no income" do
      params[:from] = "2026-01-01"

      allow(report).to receive_messages(grouped_income: {}, display_formula_income: 0, care_products_income: 0)

      expect(presentation.show_content?).to be(true)
    end
  end

  describe "#filters_applied?" do
    it "returns false without filters" do
      expect(presentation.filters_applied?).to be(false)
    end

    [
      { all_time: "1" },
      { from: "2026-01-01" },
      { to: "2026-01-31" },
      { income_groups_applied: "1" },
      { income_categories: [ "haircut" ] },
      { service_ids: [ "1" ] },
      { formula_kinds: [ "color" ] },
      { formula_product_ids: [ "11" ] },
      { care_product_ids: [ "21" ] }
    ].each do |filter|
      it "detects #{filter.keys.first}" do
        params.merge!(filter)

        expect(presentation.filters_applied?).to be(true)
      end
    end

    it "ignores empty filter arrays" do
      params[:service_ids] = []

      expect(presentation.filters_applied?).to be(false)
    end
  end

  describe "#formula_sections" do
    it "returns all nonempty sections with totals and titles" do
      expect(presentation.formula_sections).to eq([
        { kind: "color", title_key: "formula_products.tabs.colors", items: colors, total: 30.0 },
        { kind: "additive", title_key: "formula_products.tabs.additives", items: additives, total: 5.0 },
        { kind: "oxidant", title_key: "analytics.income.oxidants", items: oxidants, total: 25.0 }
      ])
    end

    it "filters sections by selected formula kinds" do
      allow(report).to receive_messages(income_groups_applied: true, formula_kinds: [ "oxidant" ])

      expect(presentation.formula_sections.pluck(:kind)).to eq([ "oxidant" ])
    end

    it "shows all kinds when no kinds are explicitly selected" do
      allow(report).to receive_messages(income_groups_applied: true, formula_kinds: [])

      expect(presentation.formula_sections.pluck(:kind)).to eq(%w[color additive oxidant])
    end

    it "skips empty item lists" do
      allow(report).to receive(:additive_income).and_return([])

      expect(presentation.formula_sections.pluck(:kind)).to eq(%w[color oxidant])
    end

    it "handles numeric strings and nil amounts" do
      allow(report).to receive(:formula_color_income).and_return([ { amount: "4.5" }, { amount: nil } ])

      expect(presentation.formula_sections.first[:total]).to eq(4.5)
    end
  end

  describe "#category_params" do
    it "preserves filters and expands a category" do
      expect(presentation.category_params("haircut")).to eq(
        tab: "income",
        income_categories: [ "haircut" ],
        service_ids: [ 1 ],
        formula_product_ids: [ 11 ],
        care_product_ids: [ 21 ],
        income_groups: [],
        formula_kinds: [],
        expanded: "haircut"
      )
    end

    it "collapses an already expanded category" do
      allow(report).to receive(:expanded_income_category).and_return("haircut")

      expect(presentation.category_params("haircut")).not_to have_key(:expanded)
    end

    it "preserves applied income group filters" do
      allow(report).to receive_messages(income_groups_applied: true, income_groups: [ "services" ])

      expect(presentation.category_params("haircut")).to include(income_groups_applied: "1", income_groups: [ "services" ])
    end

    it "preserves an explicit period in display format" do
      params[:from] = "2026-01-01"

      expect(presentation.category_params("haircut")).to include(from: "01.01.2026", to: "31.01.2026")
    end

    it "preserves an explicit end date" do
      params[:to] = "2026-01-31"

      expect(presentation.category_params("haircut")).to include(from: "01.01.2026", to: "31.01.2026")
    end

    context "with all-time selected" do
      let(:all_time) { true }

      it "uses all_time instead of date range" do
        params[:from] = "2026-01-01"

        result = presentation.category_params("haircut")

        expect(result).to include(all_time: "1")
        expect(result).not_to have_key(:from)
        expect(result).not_to have_key(:to)
      end
    end
  end
end

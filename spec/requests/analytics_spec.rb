require "rails_helper"

RSpec.describe "Analytics" do
  include Devise::Test::IntegrationHelpers
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, :trial) }
  let(:other_user) { create(:user) }
  let(:from) { 1.month.ago.to_date }
  let(:to) { Date.current }

  before do
    travel_to Time.zone.local(2026, 1, 15)
    sign_in user, scope: :user
  end

  after { travel_back }

  describe "GET /analytics" do
    it "defaults to income when tab is missing" do
      get analytics_path

      expect(response).to have_http_status(:ok)
      expect(controller.instance_variable_get(:@analytics_tab)).to eq("income")
    end

    it "defaults to income when tab is invalid" do
      get analytics_path(tab: "invalid")

      expect(response).to have_http_status(:ok)
      expect(controller.instance_variable_get(:@analytics_tab)).to eq("income")
    end

    it "loads expenses when tab is expenses" do
      get analytics_path(tab: "expenses")

      expect(response).to have_http_status(:ok)
      expect(controller.instance_variable_get(:@analytics_tab)).to eq("expenses")
    end

    it "loads balance when tab is balance" do
      get analytics_path(tab: "balance")

      expect(response).to have_http_status(:ok)
      expect(controller.instance_variable_get(:@analytics_tab)).to eq("balance")
    end
  end

  describe "analytics redirects" do
    it "redirects income to analytics with income tab" do
      get income_analytics_path, params: { from: "01.01.2026", to: "15.01.2026" }

      expect(response).to redirect_to(analytics_path(tab: "income", from: "01.01.2026", to: "15.01.2026"))
    end

    it "redirects expenses to analytics with expenses tab" do
      get expenses_analytics_path, params: { from: "01.01.2026", to: "15.01.2026" }

      expect(response).to redirect_to(
        analytics_path(tab: "expenses", from: "01.01.2026", to: "15.01.2026")
      )
    end

    it "redirects balance to analytics with balance tab" do
      get balance_analytics_path, params: { from: "01.01.2026", to: "15.01.2026" }

      expect(response).to redirect_to(analytics_path(tab: "balance", from: "01.01.2026", to: "15.01.2026"))
    end
  end

  describe "GET /analytics/expenses" do
    it "filters expenses by user, period and category" do
      rent = create(:expense, user: user, category: "rent", amount: 100, spent_on: Date.current)
      create(:expense, user: user, category: "materials", amount: 200, spent_on: Date.current)
      create(:expense, user: user, category: "rent", amount: 300, spent_on: 2.months.ago.to_date)
      create(:expense, user: other_user, category: "rent", amount: 400, spent_on: Date.current)

      get analytics_path(tab: "expenses"), params: { from: from, to: to, categories: [ "rent" ] }

      expect(response).to have_http_status(:ok)

      scope = Expense.for_user_between(user, from, to).apply_category_filter([ "rent" ])

      expect(scope).to contain_exactly(rent)
      expect(Expense.total_expenses(scope)).to eq(100)
      expect(Expense.grouped_expenses(scope)).to eq({ "rent" => 100 })
    end

    it "accepts valid category filters" do
      get analytics_path(tab: "expenses"), params: { categories: [ "rent", "materials" ] }

      expect(response).to have_http_status(:ok)
      expect(controller.instance_variable_get(:@category_filters)).to eq([ "rent", "materials" ])
    end

    it "ignores invalid category filters" do
      get analytics_path(tab: "expenses"), params: { categories: [ "rent", "INVALID_CATEGORY" ] }

      expect(response).to have_http_status(:ok)
      expect(controller.instance_variable_get(:@category_filters)).to eq([ "rent" ])
    end

    it "falls back to default dates when invalid dates passed" do
      get analytics_path(tab: "expenses"), params: { from: "INVALID_DATE", to: "INVALID_DATE" }

      expect(response).to have_http_status(:ok)
    end

    context "without period params" do
      it "shows expenses from all time by default" do
        current_expense = create(:expense, user: user, category: "rent", amount: 100, spent_on: Date.current)
        historical_expense = create(:expense, user: user, category: "materials", amount: 200, spent_on: 1.year.ago.to_date)

        get analytics_path(tab: "expenses")

        expect(response).to have_http_status(:ok)
        expect(controller.instance_variable_get(:@expenses)).to contain_exactly(current_expense, historical_expense)
        expect(controller.instance_variable_get(:@total_expenses)).to eq(300)
      end
    end
  end

  describe "GET /analytics/income" do
    let(:client) { create(:client, user: user) }
    let(:service_a) { create(:service, user: user, service_type: "service", category: "haircut", subtype: "A", price: 100) }
    let(:service_b) { create(:service, user: user, service_type: "service", category: "coloring", subtype: "B", price: 200) }
    let(:other_service) { create(:service, user: other_user, service_type: "service", category: "haircut", subtype: "X", price: 999) }
    let(:care_product) do
      create(:care_product, user: user, brand: "Test", name: "Mask", category: "Mask",
              purchase_price: 30, sale_price: 50, stock_quantity: 10)
    end

    let(:care_products) do
      [ { "care_product_id" => care_product.id, "name" => care_product.display_name, "price" => 50, "purchase_price" => 30, "qty" => 2 } ]
    end

    let(:appointment_a) do
      create(:appointment, user: user, client: client, appointment_date: Date.current, appointment_time: "10:00", end_time: "10:30",
            main_service: service_a)
    end
    let(:appointment_b) do
      create(:appointment, user: user, client: client,
              appointment_date: Date.current,
              appointment_time: "11:00",
              end_time: "11:30",
              main_service: service_b)
    end

    let(:service_note_b) do
      note = build(:service_note, :without_services, appointment: appointment_b, user: user, client: client)
      note.services = [ service_b ]
      note.save!
      note
    end

    def income_report
      controller.instance_variable_get(:@income_report)
    end

    def total_income
      income_report.total_income
    end

    def grouped_income
      income_report.grouped_income
    end

    def monthly_income
      income_report.monthly_income
    end

    before do
      appointment_a
      appointment_b

      other_client = create(:client, user: other_user)
      create(:appointment, user: other_user, client: other_client,
              appointment_date: Date.current,
              appointment_time: "12:00",
              end_time: "12:30",
              main_service: other_service)
    end

    it "returns success response" do
      get analytics_path(tab: "income"), params: { from: from, to: to }

      expect(response).to have_http_status(:ok)
    end

    it "calculates income from historical service prices" do
      get analytics_path(tab: "income"), params: { from: from, to: to }

      expect(total_income).to eq(300)
    end

    it "keeps historical service prices after catalog prices change" do
      service_a.update!(price: 500)
      service_b.update!(price: 800)

      get analytics_path(tab: "income"), params: { from: from, to: to }

      expect(total_income).to eq(300)
    end

    it "groups historical service income by category" do
      get analytics_path(tab: "income"), params: { from: from, to: to }

      expect(grouped_income).to eq({ "haircut" => 100, "coloring" => 200 })
    end

    it "includes formula ingredient income" do
      color_product = create(:formula_product, user: user, category: "color", brand: "Wella", name: "7/1", unit: "g")

      formula_step = create(:formula_step, service_note: service_note_b)

      create(:formula_ingredient, formula_step: formula_step, formula_product: color_product, amount: 10, price: 5)

      Formulas::SyncCharges.new(service_note: service_note_b.reload).call

      get analytics_path(tab: "income"), params: { from: from, to: to }

      expect(total_income).to eq(350)
    end

    it "includes oxidant income" do
      oxidant_product = create(:formula_product, :oxidant, user: user, brand: "Wella", name: "6%", unit: "ml")

      create(:formula_step, service_note: service_note_b,
        oxidant: [ { "formula_product_id" => oxidant_product.id, "amount" => 20, "price" => 2 } ])

      Formulas::SyncCharges.new(service_note: service_note_b.reload).call

      get analytics_path(tab: "income"), params: { from: from, to: to }

      expect(total_income).to eq(340)
    end

    it "includes care product sale income" do
      service_note =
        build(:service_note, :without_services, appointment: appointment_a, user: user, client: client, care_products: care_products)
      service_note.services = [ service_a ]
      service_note.save!

      get analytics_path(tab: "income"), params: { from: from, to: to }

      expect(total_income).to eq(400)
    end

    it "calculates service, formula and care product income together" do
      color_product = create(:formula_product, user: user, category: "color", brand: "Wella", name: "7/1", unit: "g")

      oxidant_product = create(:formula_product, :oxidant, user: user, brand: "Wella", name: "6%", unit: "ml")

      service_note_b.update!(care_products: care_products)

      formula_step =
        create(:formula_step, service_note: service_note_b,
          oxidant: [ { "formula_product_id" => oxidant_product.id, "amount" => 20, "price" => 2 } ])

      create(:formula_ingredient, formula_step: formula_step, formula_product: color_product, amount: 10, price: 5)

      Formulas::SyncCharges.new(service_note: service_note_b.reload).call

      get analytics_path(tab: "income"), params: { from: from, to: to }

      expect(total_income).to eq(490)
    end

    it "filters income by service category" do
      get analytics_path(tab: "income"), params: { from: from, to: to, income_categories: [ "coloring" ] }

      expect(total_income).to eq(200)
      expect(grouped_income).to eq({ "coloring" => 200 })
    end

    it "filters income by service id" do
      get analytics_path(tab: "income"), params: { from: from, to: to, service_ids: [ service_a.id ] }

      expect(total_income).to eq(100)
      expect(grouped_income).to eq({ "haircut" => 100 })
    end

    it "includes formula and care product income from appointments matching the service filter" do
      service_note_b.update!(care_products: care_products)

      expect(appointment_b.reload.appointment_services_relations.pluck(:service_id, :price)).to eq([ [ service_b.id, 200 ] ])

      get analytics_path(tab: "income"), params: { from: from, to: to, service_ids: [ service_b.id ] }

      expect(total_income).to eq(300)
    end

    it "does not include formula or care product income from appointments excluded by service filter" do
      create(:service_note, appointment: appointment_b, user: user, client: client, care_products: care_products)

      get analytics_path(tab: "income"), params: { from: from, to: to, service_ids: [ service_a.id ] }

      expect(total_income).to eq(100)
    end

    it "expands a selected income category into monthly historical relations" do
      get analytics_path(tab: "income"), params: { from: from, to: to, expanded: "haircut" }

      expect(monthly_income).to be_present

      relations = monthly_income.values.flatten

      expect(relations.map(&:service_id)).to contain_exactly(service_a.id)
      expect(relations.sum(&:price)).to eq(100)
    end

    it "does not expand an unknown income category" do
      get analytics_path(tab: "income"), params: { from: from, to: to, expanded: "unknown" }

      expect(monthly_income).to eq({})
    end

    it "ignores invalid income categories" do
      get analytics_path(tab: "income"), params: { from: from, to: to, income_categories: [ "INVALID_CATEGORY" ] }

      expect(response).to have_http_status(:ok)
      expect(total_income).to eq(300)
    end

    it "ignores invalid service ids" do
      get analytics_path(tab: "income"), params: { from: from, to: to, service_ids: [ "INVALID" ] }

      expect(response).to have_http_status(:ok)
      expect(total_income).to eq(300)
    end

    it "supports all-time income" do
      historical_appointment = create(:appointment, user: user, client: client,
                                      appointment_date: Date.current,
                                      appointment_time: "14:00",
                                      end_time: "14:30",
                                      main_service: service_a)
      historical_appointment.update_column(:appointment_date, 1.year.ago.to_date)

      get analytics_path(tab: "income"), params: { all_time: "1" }

      expect(total_income).to eq(400)
    end

    it "shows income from all time by default when no period params are provided" do
      historical_appointment = create(:appointment, user: user, client: client,
                                      appointment_date: Date.current,
                                      appointment_time: "14:00",
                                      end_time: "14:30",
                                      main_service: service_a)
      historical_appointment.update_column(:appointment_date, 1.year.ago.to_date)

      get analytics_path(tab: "income")

      expect(response).to have_http_status(:ok)
      expect(total_income).to eq(400)
    end

    it "displays only selected income groups" do
      get analytics_path(tab: "income"), params: { income_groups_applied: "1", income_groups: [ "services" ] }

      expect(income_report.display_total_income).to eq(300)
    end

    it "returns zero when no income groups are selected" do
      get analytics_path(tab: "income"), params: { income_groups_applied: "1" }

      expect(income_report.display_total_income).to eq(0)
    end
  end

  describe "GET /analytics/balance" do
    let(:client) { create(:client, user: user) }
    let(:service) { create(:service, user: user, service_type: "service", category: "haircut", subtype: "Basic", price: 100) }
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
              main_service: service)
    end

    let(:service_note) do
      note = build(:service_note, :without_services, user: user, client: client, appointment: appointment, care_products: care_products)
      note.services = [ service ]
      note.save!
      note
    end

    let(:color_product) { create(:formula_product, user: user, category: "color", brand: "Wella", name: "7/1", unit: "g") }

    let(:oxidant_product) { create(:formula_product, :oxidant, user: user, brand: "Wella", name: "6%", unit: "ml") }

    before do
      formula_step =
        create(:formula_step, service_note: service_note,
          oxidant: [ { "formula_product_id" => oxidant_product.id, "amount" => 20, "price" => 2 } ])

      create(:formula_ingredient, formula_step: formula_step, formula_product: color_product, amount: 10, price: 5)

      Formulas::SyncCharges.new(service_note: service_note.reload).call

      create(:expense, user: user, amount: 40, spent_on: Date.current)
    end

    context "with selected period" do
      before { get analytics_path(tab: "balance"), params: { from: from, to: to } }

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "displays calculated financial summary" do
        expect(response.body).to include("290")
        expect(response.body).to include("100")
        expect(response.body).to include("190")
      end
    end

    context "with historical data" do
      before do
        historical_appointment = create(:appointment, user: user, client: client,
                                        appointment_date: Date.current,
                                        appointment_time: "12:00",
                                        end_time: "12:30",
                                        main_service: service)
        historical_appointment.update_column(:appointment_date, 1.year.ago.to_date)
        create(:expense, user: user, amount: 70, spent_on: 2.years.ago.to_date)
      end

      context "with all_time" do
        before { get analytics_path(tab: "balance"), params: { all_time: "1" } }

        it "returns success" do
          expect(response).to have_http_status(:ok)
        end

        it "includes all historical income and expenses" do
          expect(response.body).to include("390")
          expect(response.body).to include("170")
          expect(response.body).to include("220")
        end
      end

      context "without period params" do
        before { get analytics_path(tab: "balance") }

        it "returns success" do
          expect(response).to have_http_status(:ok)
        end

        it "includes all historical income and expenses by default" do
          expect(response.body).to include("390")
          expect(response.body).to include("170")
          expect(response.body).to include("220")
        end
      end
    end

    it "does not count care product purchases as manual expenses in balance" do
      create(:expense, user: user, category: "care_products", amount: 48_000, spent_on: Date.current)

      get analytics_path(tab: "balance"), params: { from: Date.current.beginning_of_month.iso8601, to: Date.current.iso8601 }

      expect(response).to have_http_status(:ok)
      expect(controller.instance_variable_get(:@manual_expenses)).to eq(40)
    end

    it "shows stock value only for the current user" do
      create(:care_product, user: user, purchase_price: 800, stock_quantity: 60)
      other_product = create(:care_product, user: other_user, purchase_price: 10_000, stock_quantity: 100)

      get analytics_path(tab: "balance")

      stock_value = controller.instance_variable_get(:@care_products_stock_value)

      expect(stock_value).to eq(user.care_products.total_stock_value)
      expect(stock_value).not_to eq(other_product.stock_value)
    end
  end

  describe "GET /analytics/income_filter_options" do
    let(:path) { analytics_income_filter_options_path }

    it "returns income filter options with the selected period" do
      get path, params: { from: "01.01.2026", to: "15.01.2026" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["period"]).to eq("from" => "2026-01-01", "to" => "2026-01-15")
    end

    it "uses income appointment dates for all-time period" do
      client = create(:client, user: user)
      service = create(:service, user: user)

      create(:appointment, user: user, client: client, main_service: service, appointment_date: Date.new(2025, 6, 10))

      get path, params: { all_time: "1" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["period"]).to eq("from" => "2025-06-10", "to" => "2025-06-10")
    end

    it "uses current date when no appointments exist" do
      get path, params: { all_time: "1" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["period"]).to eq("from" => "2026-01-15", "to" => "2026-01-15")
    end
  end

  describe "GET /analytics/expenses all-time period" do
    it "uses earliest and latest expense dates" do
      create(:expense, user: user, spent_on: Date.new(2024, 3, 10))
      create(:expense, user: user, spent_on: Date.new(2025, 9, 20))

      get analytics_path(tab: "expenses"), params: { all_time: "1" }

      expect(response).to have_http_status(:ok)
      expect(controller.instance_variable_get(:@from)).to eq(Date.new(2024, 3, 10))
      expect(controller.instance_variable_get(:@to)).to eq(Date.new(2025, 9, 20))
    end

    it "uses current date when no expenses exist" do
      get analytics_path(tab: "expenses"), params: { all_time: "1" }

      expect(response).to have_http_status(:ok)
      expect(controller.instance_variable_get(:@from)).to eq(Date.current)
      expect(controller.instance_variable_get(:@to)).to eq(Date.current)
    end
  end

  describe "GET /analytics/income all-time period" do
    let(:client) { create(:client, user: user) }
    let(:service) { create(:service, user: user) }

    it "uses earliest and latest appointment dates" do
      create(:appointment, user: user, client: client, main_service: service,
        appointment_date: Date.new(2024, 5, 10), appointment_time: "10:00")

      create(:appointment, user: user, client: client, main_service: service,
        appointment_date: Date.new(2026, 1, 15), appointment_time: "12:00")

      get analytics_path(tab: "income"), params: { all_time: "1" }

      expect(response).to have_http_status(:ok)
      expect(controller.instance_variable_get(:@from)).to eq(Date.new(2024, 5, 10))
      expect(controller.instance_variable_get(:@to)).to eq(Date.new(2026, 1, 15))
    end

    it "uses current date when no appointments exist" do
      get analytics_path(tab: "income"), params: { all_time: "1" }

      expect(response).to have_http_status(:ok)
      expect(controller.instance_variable_get(:@from)).to eq(Date.current)
      expect(controller.instance_variable_get(:@to)).to eq(Date.current)
    end
  end

  describe "GET /analytics/balance empty all-time period" do
    it "uses current date when there are no financial records" do
      get analytics_path(tab: "balance"), params: { all_time: "1" }

      expect(response).to have_http_status(:ok)
      expect(controller.instance_variable_get(:@from)).to eq(Date.current)
      expect(controller.instance_variable_get(:@to)).to eq(Date.current)
    end
  end
end

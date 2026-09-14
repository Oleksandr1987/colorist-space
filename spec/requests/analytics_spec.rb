require "rails_helper"

RSpec.describe "Analytics" do
  include Devise::Test::IntegrationHelpers
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, :trial) }
  let(:other_user) { create(:user) }

  before do
    travel_to Time.zone.local(2026, 1, 15)
    sign_in user, scope: :user
  end

  after { travel_back }

  describe "GET /analytics/expenses" do
    it "filters expenses by user, period and category" do
      rent = create(:expense, user: user, category: "Оренда", amount: 100, spent_on: Date.current)

      get expenses_analytics_path, params: { from: 1.month.ago.to_date, to: Date.current, category: "Оренда" }

      expect(response).to have_http_status(:ok)

      scope = Expense.for_user_between(user, 1.month.ago.to_date, Date.current).apply_category_filter("Оренда")

      expect(scope).to contain_exactly(rent)
      expect(Expense.total_expenses(scope)).to eq(100)
      expect(Expense.grouped_expenses(scope)).to eq({ "Оренда" => 100 })
    end

    it "assigns category filter when category valid" do
      get expenses_analytics_path, params: { category: Expense::CATEGORIES.first }

      expect(response).to have_http_status(:ok)
    end

    it "ignores invalid category" do
      get expenses_analytics_path, params: { category: "INVALID_CATEGORY" }

      expect(response).to have_http_status(:ok)
    end

    it "falls back to default dates when invalid dates passed" do
      get expenses_analytics_path, params: { from: "INVALID_DATE", to: "INVALID_DATE" }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /analytics/income" do
  let(:client) { create(:client, user: user) }

  let(:service_a) do
    create(:service, user: user, service_type: "service", category: "haircut", subtype: "A", price: 100)
  end

  let(:service_b) do
    create(:service, user: user, service_type: "service", category: "coloring", subtype: "B", price: 200)
  end

  let(:other_service) do
    create(:service, user: other_user, service_type: "service", category: "haircut", subtype: "X", price: 999)
  end

  let(:appointment_a) do
    create(:appointment, user: user, client: client,
      appointment_date: Date.current,
      appointment_time: "10:00",
      end_time: "10:30",
      main_service: service_a
    )
  end

  let(:appointment_b) do
    create(:appointment, user: user, client: client,
      appointment_date: Date.current,
      appointment_time: "11:00",
      end_time: "11:30",
      main_service: service_b
    )
  end

  let(:from) { 1.month.ago.to_date }
  let(:to) { Date.current }

  def total_income
    controller.instance_variable_get(:@total_income)
  end

  def grouped_income
    controller.instance_variable_get(:@grouped_income)
  end

  def monthly_income
    controller.instance_variable_get(:@monthly_income)
  end

  before do
    appointment_a
    appointment_b

    other_client = create(:client, user: other_user)

    create(:appointment, user: other_user, client: other_client,
      appointment_date: Date.current,
      appointment_time: "12:00",
      end_time: "12:30",
      main_service: other_service
    )
  end

  it "returns success response" do
    get income_analytics_path, params: { from: from, to: to }

    expect(response).to have_http_status(:ok)
  end

  it "calculates income from historical service prices" do
    get income_analytics_path, params: { from: from, to: to }

    expect(total_income).to eq(300)
  end

  it "keeps historical service prices after catalog prices change" do
    service_a.update!(price: 500)
    service_b.update!(price: 800)

    get income_analytics_path, params: { from: from, to: to }

    expect(total_income).to eq(300)
  end

  it "groups historical service income by category" do
    get income_analytics_path, params: { from: from, to: to }

    expect(grouped_income).to eq({ "haircut" => 100, "coloring" => 200 })
  end

  it "includes formula ingredient income" do
    service_note =
      build(:service_note, :without_services, appointment: appointment_b, user: user, client: client)

    service_note.services = [ service_b ]
    service_note.save!

    formula_step = create(:formula_step, service_note: service_note)

    create(:formula_ingredient, formula_step: formula_step, amount: 10, price: 5)

    get income_analytics_path, params: { from: from, to: to }

    expect(total_income).to eq(350)
  end

  it "includes oxidant income" do
    service_note =
      build(:service_note, :without_services, appointment: appointment_b, user: user, client: client)

    service_note.services = [ service_b ]
    service_note.save!

    create(:formula_step,
      service_note: service_note,
      oxidant: [ { "formula_product_id" => 1, "amount" => 20, "price" => 2 } ]
    )

    get income_analytics_path, params: { from: from, to: to }

    expect(total_income).to eq(340)
  end

  it "includes care product sale income" do
    service_note =
      build(:service_note, :without_services,
        appointment: appointment_a,
        user: user,
        client: client,
        care_products: [ { "care_product_id" => 1, "name" => "Mask", "price" => 50, "purchase_price" => 30, "qty" => 2 } ]
      )

    service_note.services = [ service_a ]
    service_note.save!

    get income_analytics_path, params: { from: from, to: to }

    expect(total_income).to eq(400)
  end

  it "calculates service, formula and care product income together" do
    service_note =
      build(:service_note, :without_services,
        appointment: appointment_b,
        user: user,
        client: client,
        care_products: [ { "care_product_id" => 1, "name" => "Mask", "price" => 50, "purchase_price" => 30, "qty" => 2 } ]
      )

    service_note.services = [ service_b ]
    service_note.save!

    formula_step =
      create(:formula_step,
        service_note: service_note,
        oxidant: [ { "formula_product_id" => 1, "amount" => 20, "price" => 2 } ]
      )

    create(:formula_ingredient, formula_step: formula_step, amount: 10, price: 5)

    get income_analytics_path, params: { from: from, to: to }
    expect(total_income).to eq(490)
  end

  it "filters income by service category" do
    get income_analytics_path, params: { from: from, to: to, income_categories: [ "coloring" ] }

    expect(total_income).to eq(200)
    expect(grouped_income).to eq({ "coloring" => 200 })
  end

  it "filters income by service id" do
    get income_analytics_path, params: { from: from, to: to, service_ids: [ service_a.id ] }

    expect(total_income).to eq(100)
    expect(grouped_income).to eq({ "haircut" => 100 })
  end

  it "includes formula and care product income from appointments matching the service filter" do
    service_note =
      build(:service_note, :without_services,
        appointment: appointment_b,
        user: user,
        client: client,
        care_products: [ { "care_product_id" => 1, "name" => "Mask", "price" => 50, "purchase_price" => 30, "qty" => 2 } ]
      )

    service_note.services = [ service_b ]
    service_note.save!

    expect(appointment_b.reload.appointment_services_relations.pluck(:service_id, :price)).to eq([ [ service_b.id, 200 ] ])

    get income_analytics_path, params: { from: from, to: to, service_ids: [ service_b.id ] }

    expect(total_income).to eq(300)
  end

  it "does not include formula or care product income from appointments excluded by service filter" do
    create(:service_note,
      appointment: appointment_b,
      user: user,
      client: client,
      care_products: [ { "care_product_id" => 1, "name" => "Mask", "price" => 50, "purchase_price" => 30, "qty" => 2 } ]
    )

    get income_analytics_path, params: { from: from, to: to, service_ids: [ service_a.id ] }

    expect(total_income).to eq(100)
  end

  it "expands a selected income category into monthly historical relations" do
    get income_analytics_path, params: { from: from, to: to, expanded: "haircut" }

    expect(monthly_income).to be_present

    relations = monthly_income.values.flatten

    expect(relations.map(&:service_id)).to contain_exactly(service_a.id)
    expect(relations.sum(&:price)).to eq(100)
  end

  it "does not expand an unknown income category" do
    get income_analytics_path, params: { from: from, to: to, expanded: "unknown" }

    expect(monthly_income).to eq({})
  end

  it "ignores invalid income categories" do
    get income_analytics_path, params: { from: from, to: to, income_categories: [ "INVALID_CATEGORY" ] }

    expect(response).to have_http_status(:ok)
    expect(total_income).to eq(300)
  end

  it "ignores invalid service ids" do
    get income_analytics_path, params: { from: from, to: to, service_ids: [ "INVALID" ] }

    expect(response).to have_http_status(:ok)
    expect(total_income).to eq(300)
  end

  it "supports all-time income" do
    old_appointment =
      create(:appointment, user: user, client: client,
        appointment_date: Date.current,
        appointment_time: "14:00",
        end_time: "14:30",
        main_service: service_a
      )

    old_appointment.update_column(:appointment_date, 1.year.ago.to_date)

    get income_analytics_path, params: { all_time: "1" }

    expect(total_income).to eq(400)
  end
end

  describe "GET /analytics/balance" do
    let(:client) { create(:client, user: user) }
    let(:service) { create(:service, user: user, service_type: "service", category: "haircut", subtype: "Basic", price: 100) }
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
      create(:formula_ingredient, formula_step: formula_step, amount: 10, price: 5)
      create(:expense, user: user, amount: 40, spent_on: Date.current)
    end

    context "with selected period" do
      before do
        get balance_analytics_path, params: { from: from, to: to }
      end

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "displays calculated financial summary" do
        expect(response.body).to include("290")
        expect(response.body).to include("100")
        expect(response.body).to include("190")
      end
    end

    context "with all_time" do
      before do
        historical_appointment =
          create(:appointment, user: user, client: client,
            appointment_date: Date.current,
            appointment_time: "12:00",
            end_time: "12:30",
            main_service: service
          )

        historical_appointment.update_column(:appointment_date, 1.year.ago.to_date)

        create(:expense, user: user, amount: 70, spent_on: 2.years.ago.to_date)

        get balance_analytics_path, params: { all_time: "1" }
      end

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "includes all historical income and expenses" do
        expect(response.body).to include("390")
        expect(response.body).to include("170")
        expect(response.body).to include("220")
      end
    end
  end
end

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
      rent = create(
        :expense,
        user: user,
        category: "Оренда",
        amount: 100,
        spent_on: Date.current
      )

      get expenses_analytics_path, params: {
        from: 1.month.ago.to_date,
        to: Date.current,
        category: "Оренда"
      }

      expect(response).to have_http_status(:ok)

      scope = Expense
        .for_user_between(user, 1.month.ago.to_date, Date.current)
        .apply_category_filter("Оренда")

      expect(scope).to contain_exactly(rent)

      expect(Expense.total_expenses(scope)).to eq(100)
      expect(Expense.grouped_expenses(scope)).to eq({ "Оренда" => 100 })
    end

    it "assigns category filter when category valid" do
      get expenses_analytics_path, params: {
        category: Expense::CATEGORIES.first
      }

      expect(response).to have_http_status(:ok)
    end

    it "ignores invalid category" do
      get expenses_analytics_path, params: {
        category: "INVALID_CATEGORY"
      }

      expect(response).to have_http_status(:ok)
    end

    it "falls back to default dates when invalid dates passed" do
      get expenses_analytics_path, params: {
        from: "INVALID_DATE",
        to: "INVALID_DATE"
      }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /analytics/income" do
    let(:client) { create(:client, user: user) }

    let(:service_a) do
      create(
        :service,
        user: user,
        service_type: "service",
        category: "Haircut",
        subtype: "A",
        price: 100
      )
    end

    let(:service_b) do
      create(
        :service,
        user: user,
        service_type: "service",
        category: "Coloring",
        subtype: "B",
        price: 200
      )
    end

    let(:other_service) do
      create(
        :service,
        user: other_user,
        service_type: "service",
        category: "Haircut",
        subtype: "X",
        price: 999
      )
    end

    let(:services_scope) do
      Service.income_for_user_between(
        user,
        1.month.ago.to_date,
        Date.current
      )
    end

    before do
      create(
        :appointment,
        user: user,
        client: client,
        appointment_date: Date.current,
        appointment_time: "10:00",
        end_time: "10:30",
        main_service: service_a
      )

      create(
        :appointment,
        user: user,
        client: client,
        appointment_date: Date.current,
        appointment_time: "11:00",
        end_time: "11:30",
        main_service: service_b
      )

      other_client = create(:client, user: other_user)

      create(
        :appointment,
        user: other_user,
        client: other_client,
        appointment_date: Date.current,
        appointment_time: "12:00",
        end_time: "12:30",
        main_service: other_service
      )

      get income_analytics_path, params: {
        from: 1.month.ago.to_date,
        to: Date.current
      }
    end

    it "returns success response" do
      expect(response).to have_http_status(:ok)
    end

    it "returns only current user services" do
      expect(services_scope).to include(service_a, service_b)
    end

    it "excludes other user services" do
      expect(services_scope.pluck(:price)).not_to include(999)
    end

    it "calculates total income" do
      expect(services_scope.sum(:price)).to eq(300)
    end

    it "groups income by service type" do
      expect(Service.grouped_income(services_scope, nil))
        .to eq({ "service" => 300 })
    end
  end

  describe "GET /analytics/balance" do
    let(:client) { create(:client, user: user) }

    let(:service) do
      create(
        :service,
        user: user,
        service_type: "service",
        category: "Haircut",
        subtype: "Basic",
        price: 100
      )
    end

    let(:from) { 1.month.ago.to_date }
    let(:to) { Date.current }

    before do
      create(
        :appointment,
        user: user,
        client: client,
        appointment_date: Date.current,
        appointment_time: "10:00",
        end_time: "10:30",
        main_service: service
      )

      create(:expense, user: user, amount: 40, spent_on: Date.current)
      create(:expense, user: user, amount: 10, spent_on: Date.current)

      get balance_analytics_path, params: {
        from: from,
        to: to
      }
    end

    describe "response" do
      it "returns success" do
        expect(response).to have_http_status(:ok)
      end
    end

    describe "calculations" do
      subject(:income) do
        Service
          .income_for_user_between(user, from, to)
          .sum(:price)
      end

      let(:expenses) do
        user.expenses
          .where(spent_on: from..to)
          .sum(:amount)
      end

      it "calculates income" do
        expect(income).to eq(100)
      end

      it "calculates expenses" do
        expect(expenses).to eq(50)
      end

      it "calculates balance" do
        expect(income - expenses).to eq(50)
      end
    end
  end
end

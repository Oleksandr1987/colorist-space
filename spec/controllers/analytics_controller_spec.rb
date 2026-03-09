require "rails_helper"

RSpec.describe AnalyticsController, type: :controller do
  include Devise::Test::ControllerHelpers
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  before do
    travel_to Time.zone.local(2026, 1, 15)
    request.env["devise.mapping"] = Devise.mappings[:user]
    allow(request.env["warden"]).to receive(:authenticate!).and_return(user)
    allow(controller).to receive(:current_user).and_return(user)
  end

  after { travel_back }

  describe "GET #expenses" do
    it "filters expenses by user, period and category" do
      rent = create(:expense,
        user: user,
        category: "Оренда",
        amount: 100,
        spent_on: Date.current
      )

      get :expenses, params: {
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
  end

  describe "GET #income" do
    let(:client) { create(:client, user: user) }

    it "returns income only for current user in period" do
      service_a = create(:service,
        user: user,
        service_type: "service",
        category: "Haircut",
        subtype: "A",
        price: 100
      )

      service_b = create(:service,
        user: user,
        service_type: "service",
        category: "Coloring",
        subtype: "B",
        price: 200
      )

      create(:appointment,
        user: user,
        client: client,
        appointment_date: Date.current,
        appointment_time: Time.zone.parse("10:00"),
        end_time: Time.zone.parse("10:30"),
        main_service: service_a
      )

      create(:appointment,
        user: user,
        client: client,
        appointment_date: Date.current,
        appointment_time: Time.zone.parse("11:00"),
        end_time: Time.zone.parse("11:30"),
        main_service: service_b
      )

      other_service = create(:service,
        user: other_user,
        service_type: "service",
        category: "Haircut",
        subtype: "X",
        price: 999
      )

      other_client = create(:client, user: other_user)

      create(:appointment,
        user: other_user,
        client: other_client,
        appointment_date: Date.current,
        appointment_time: Time.zone.parse("12:00"),
        end_time: Time.zone.parse("12:30"),
        main_service: other_service
      )

      get :income, params: {
        from: 1.month.ago.to_date,
        to: Date.current
      }

      expect(response).to have_http_status(:ok)

      services = Service
        .income_for_user_between(user, 1.month.ago.to_date, Date.current)

      expect(services).to include(service_a, service_b)
      expect(services.pluck(:price)).not_to include(999)

      expect(services.sum(:price)).to eq(300)
      expect(Service.grouped_income(services, nil)).to eq({ "service" => 300 })
    end

    it "groups services by subtype when filtering by service_type" do
      service_a = create(:service,
        user: user,
        service_type: "service",
        category: "Haircut",
        subtype: "Fade",
        price: 100
      )

      service_b = create(:service,
        user: user,
        service_type: "service",
        category: "Haircut",
        subtype: "Classic",
        price: 150
      )

      client = create(:client, user: user)

      create(:appointment,
        user: user,
        client: client,
        appointment_date: Date.current,
        appointment_time: Time.zone.parse("10:00"),
        end_time: Time.zone.parse("10:30"),
        main_service: service_a
      )

      create(:appointment,
        user: user,
        client: client,
        appointment_date: Date.current,
        appointment_time: Time.zone.parse("11:00"),
        end_time: Time.zone.parse("11:30"),
        main_service: service_b
      )

      get :income, params: {
        service_type: "service",
        subtype: "Fade",
        from: 1.month.ago.to_date,
        to: Date.current
      }

      expect(response).to have_http_status(:ok)

      services = Service
        .income_for_user_between(user, 1.month.ago.to_date, Date.current)
        .apply_income_filters(service_type: "service", subtype: "Fade")

      expect(services).to contain_exactly(service_a)

      expect(Service.grouped_income(services, "service")).to eq({ "Fade" => 100 })
      expect(services.sum(:price)).to eq(100)
    end
  end

  describe "GET #balance" do
    it "calculates income minus expenses" do
      client = create(:client, user: user)

      service = create(:service,
        user: user,
        service_type: "service",
        category: "Haircut",
        subtype: "Basic",
        price: 100
      )

      create(:appointment,
        user: user,
        client: client,
        appointment_date: Date.current,
        appointment_time: Time.zone.parse("10:00"),
        end_time: Time.zone.parse("10:30"),
        main_service: service
      )

      create(:expense,
        user: user,
        amount: 40,
        spent_on: Date.current
      )

      create(:expense,
        user: user,
        amount: 10,
        spent_on: Date.current
      )

      get :balance, params: {
        from: 1.month.ago.to_date,
        to: Date.current
      }

      expect(response).to have_http_status(:ok)

      income = Service
        .income_for_user_between(user, 1.month.ago.to_date, Date.current)
        .sum(:price)

      expenses = user.expenses
        .where(spent_on: 1.month.ago.to_date..Date.current)
        .sum(:amount)

      expect(income).to eq(100)
      expect(expenses).to eq(50)
      expect(income - expenses).to eq(50)
    end
  end
end

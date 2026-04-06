require "rails_helper"

RSpec.describe "Expenses", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user, :trial) }
  let(:expense) { create(:expense, user: user) }

  before do
    sign_in user, scope: :user
  end

  describe "GET /expenses" do
    it "returns success" do
      create(:expense, user: user)

      get expenses_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /expenses/new" do
    it "renders new page" do
      get new_expense_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /expenses" do
    it "creates expense" do
      params = {
        expense: {
          category: "Матеріали",
          amount: 100,
          spent_on: Date.today,
          note: "Test expense"
        }
      }

      expect {
        post expenses_path, params: params
      }.to change(user.expenses, :count).by(1)

      expect(response).to redirect_to(expenses_url(locale: I18n.locale))
    end

    it "renders new when invalid" do
      params = {
        expense: {
          category: "",
          amount: -1,
          spent_on: Date.today
        }
      }

      post expenses_path, params: params

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /expenses/:id/edit" do
    it "renders edit page" do
      get edit_expense_path(expense)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /expenses/:id" do
    it "updates expense" do
      patch expense_path(expense), params: {
        expense: {
          amount: 200
        }
      }

      expect(response).to redirect_to(expenses_url(locale: I18n.locale))
      expect(expense.reload.amount).to eq(200)
    end

    it "renders edit when invalid" do
      patch expense_path(expense), params: {
        expense: {
          amount: -10
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /expenses/:id" do
    it "destroys expense" do
      expense

      expect {
        delete expense_path(expense)
      }.to change(Expense, :count).by(-1)

      expect(response).to redirect_to(expenses_url(locale: I18n.locale))
    end
  end
end

require "rails_helper"

RSpec.describe "Expenses" do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user, :trial) }
  let(:expense) { create(:expense, user: user) }

  before do
    sign_in user, scope: :user
  end

  describe "GET /expenses/new" do
    it "renders new page" do
      get new_expense_path

      expect(response).to have_http_status(:ok)
    end

    it "shows only manually available expense categories" do
      get new_expense_path

      expect(response.body).to include('value="rent"')
      expect(response.body).not_to include('value="care_products"')
    end
  end

  describe "POST /expenses" do
    it "creates expense" do
      params = { expense: { category: "materials", amount: 100, spent_on: Date.today, note: "Test expense" } }

      expect { post expenses_path, params: params }.to change(user.expenses, :count).by(1)
      expect(response).to redirect_to(expenses_analytics_path(locale: I18n.locale))
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

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not allow creating care product expense manually" do
      params = { expense: { category: "care_products", amount: 8_000, spent_on: Date.today, note: "Care products" } }

      expect { post expenses_path, params: params }.not_to change(user.expenses, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not allow creating expense with unknown category" do
      params = { expense: { category: "unknown", amount: 100, spent_on: Date.today } }

      expect { post expenses_path, params: params }.not_to change(user.expenses, :count)
      expect(response).to have_http_status(:unprocessable_content)
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
      patch expense_path(expense), params: { expense: { amount: 200 } }

      expect(response).to redirect_to(expenses_analytics_path(locale: I18n.locale))
      expect(expense.reload.amount).to eq(200)
    end

    it "renders edit when invalid" do
      patch expense_path(expense), params: { expense: { amount: -10 } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not allow changing category to care products" do
      expense = create(:expense, user: user, category: "rent")

      patch expense_path(expense), params: { expense: { category: "care_products" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(expense.reload.category).to eq("rent")
    end
  end

  describe "DELETE /expenses/:id" do
    it "destroys expense" do
      expense

      expect { delete expense_path(expense) }.to change(Expense, :count).by(-1)
      expect(response).to redirect_to(expenses_analytics_path(locale: I18n.locale))
    end
  end
end

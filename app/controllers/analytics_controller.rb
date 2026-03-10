class AnalyticsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_period

  helper_method :permitted_params

  def show; end

  def expenses
    category_param = permitted_params[:category]

    @category_filter =
      if Expense::CATEGORIES.include?(category_param)
        category_param
      else
        nil
      end

    @expenses = Expense
                  .for_user_between(current_user, @from, @to)
                  .apply_category_filter(@category_filter)

    @grouped_expenses = Expense.grouped_expenses(@expenses)
    @total_expenses = Expense.total_expenses(@expenses)

    if @category_filter.present?
      @monthly_expenses = Expense.monthly_expenses(@expenses)
    end
  end

  def income
    filters = permitted_params.slice(:service_type, :category, :subtype)

    @services = Service
      .income_for_user_between(current_user, @from, @to)
      .apply_income_filters(filters)

    @total_income = @services.sum(:price)

    @grouped_income = Service.grouped_income(@services, filters[:service_type])

    @monthly_income_grouped = Service.monthly_income(@services)
  end

  def balance
    @total_income = Service.income_for_user_between(current_user, @from, @to).sum(:price)
    @total_expenses = current_user.expenses.where(spent_on: @from..@to).sum(:amount)
    @balance = @total_income - @total_expenses
  end

  private

  def set_period
    from = (permitted_params[:from].presence || Date.today.beginning_of_month).to_date
    to = (permitted_params[:to].presence || Date.today).to_date

    @from = [ from, to ].min
    @to = [ from, to ].max
  rescue ArgumentError
    @from = Date.today.beginning_of_month
    @to = Date.today
  end

  def permitted_params
    params.permit(:from, :to, :category, :service_type, :subtype, :commit, :locale)
  end
end

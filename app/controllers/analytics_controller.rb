class AnalyticsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_period

  def show; end

  def expenses
    @category_filter = params[:category]
    @expenses = current_user.expenses.where(spent_on: @from..@to)
    @expenses = @expenses.where(category: @category_filter) if @category_filter.present?
    @grouped_expenses = @expenses.group(:category).sum(:amount)
    @total_expenses = @expenses.sum(:amount)

    if @category_filter.present?
      @monthly_expenses = @expenses
        .order(spent_on: :desc)
        .group_by { |e| e.spent_on.strftime('%B %Y') }
    end
  end

  def income
    @total_income = Service.income_total_for_user_between(current_user, @from, @to)
  end

  def balance
    @total_income = Service.income_total_for_user_between(current_user, @from, @to)
    @total_expenses = current_user.expenses.where(spent_on: @from..@to).sum(:amount)
    @balance = @total_income - @total_expenses
  end

  private

  def set_period
    @from = (params[:from].presence || Date.today.beginning_of_month).to_date
    @to = (params[:to].presence || Date.today).to_date
  rescue ArgumentError
    @from = Date.today.beginning_of_month
    @to = Date.today
  end
end

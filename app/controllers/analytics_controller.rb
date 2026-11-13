class AnalyticsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_period

  helper_method :permitted_params, :period_filter_applied?

  def show
    @analytics_tab = %w[income expenses balance].include?(permitted_params[:tab]) ? permitted_params[:tab] : "income"

    case @analytics_tab
    when "income" then load_income
    when "expenses" then load_expenses
    when "balance" then load_balance
    end
  end

  def income
    redirect_to analytics_path(permitted_params.except(:tab).to_h.merge(tab: "income"))
  end

  def expenses
    redirect_to analytics_path(permitted_params.except(:tab).to_h.merge(tab: "expenses"))
  end

  def balance
    redirect_to analytics_path(permitted_params.except(:tab).to_h.merge(tab: "balance"))
  end

  def income_filter_options
    options = ::Analytics::IncomeFilterOptions.new(user: current_user, from: filter_from, to: filter_to)

    render json: options.call.merge(
      period: { from: @from.iso8601, to: @to.iso8601 }
    )
  end

  private

  def load_balance
    summary = ::Analytics::FinancialSummary.new(user: current_user, from: filter_from, to: filter_to)
    @service_income = summary.service_income
    @formula_income = summary.formula_income
    @care_products_income = summary.care_products_income
    @manual_expenses = summary.manual_expenses
    @care_products_cost = summary.care_products_cost
    @total_income = summary.total_income
    @total_expenses = summary.total_expenses
    @balance = summary.balance
    @care_products_stock_value = current_user.care_products.total_stock_value
  end

  def load_expenses
    @category_filters = Array(permitted_params[:categories]).select { |category| Expense::CATEGORIES.include?(category) }
    @expenses = current_user.expenses
    @expenses = @expenses.where(spent_on: @from..@to) if period_filter_applied? && !@all_time
    @expenses = @expenses.apply_category_filter(@category_filters).ordered_by_date
    @expenses_by_year = Expense.grouped_by_year_and_month(@expenses)
    @total_expenses = Expense.total_expenses(@expenses)
  end

  def load_income
    @income_report = ::Analytics::IncomeReport.new(
      user: current_user,
      from: filter_from,
      to: filter_to,
      params: permitted_params
    ).call

    @income_presentation = ::Analytics::IncomePresentation.new(
      report: @income_report,
      params: permitted_params,
      from: @from,
      to: @to,
      all_time: @all_time
    )
  end

  def filter_from
    period_filter_applied? ? @from : nil
  end

  def filter_to
    period_filter_applied? ? @to : nil
  end

  def set_period
    @all_time = permitted_params[:all_time] == "1"
    if @all_time
      @from, @to = all_time_period
      return
    end

    from = parse_date(permitted_params[:from]) || Date.current.beginning_of_month
    to = parse_date(permitted_params[:to]) || Date.current
    @from = [ from, to ].min
    @to = [ from, to ].max
  end

  def all_time_period
    active_action =
      if action_name == "show"
        permitted_params[:tab].presence_in(%w[balance income expenses]) || "balance"
      elsif action_name == "income_filter_options"
        "income"
      else
        action_name
      end

    case active_action
    when "expenses"
      [
        current_user.expenses.minimum(:spent_on) || Date.current,
        current_user.expenses.maximum(:spent_on) || Date.current
      ]
    when "income"
      dates = current_user.appointments.where.not(appointment_date: nil)
      [
        dates.minimum(:appointment_date) || Date.current,
        dates.maximum(:appointment_date) || Date.current
      ]
    when "balance"
      balance_all_time_period
    else
      [ Date.current, Date.current ]
    end
  end

  def balance_all_time_period
    appointment_dates = current_user.appointments.where.not(appointment_date: nil)
    dates = [
      appointment_dates.minimum(:appointment_date),
      appointment_dates.maximum(:appointment_date),
      current_user.expenses.minimum(:spent_on),
      current_user.expenses.maximum(:spent_on),
      current_user.care_product_sales.minimum(:sold_on),
      current_user.care_product_sales.maximum(:sold_on)
    ].compact

    return [ Date.current, Date.current ] if dates.empty?

    [ dates.min, dates.max ]
  end

  def parse_date(value)
    return if value.blank?

    Date.iso8601(value)
  rescue Date::Error
    begin
      Date.strptime(value, "%d.%m.%Y")
    rescue Date::Error
      nil
    end
  end

  def period_filter_applied?
    permitted_params[:all_time] == "1" || permitted_params.values_at(:from, :to).any?(&:present?)
  end

  def permitted_params
    params.permit(
      :tab, :from, :to, :all_time, :expanded, :category, :service_type, :subtype, :locale, :income_groups_applied,
      categories: [], income_categories: [], service_ids: [], formula_product_ids: [], care_product_ids: [],
      income_groups: [], formula_kinds: []
    )
  end
end

class AnalyticsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_period

  helper_method :permitted_params

  def show; end

  def expenses
    @category_filters =
      Array(permitted_params[:categories])
        .select { |category| Expense::CATEGORIES.include?(category) }

    @expanded_category =
      if Expense::CATEGORIES.include?(permitted_params[:expanded])
        permitted_params[:expanded]
      end

    @expenses =
      Expense
        .for_user_between(current_user, @from, @to)
        .apply_category_filter(@category_filters)
        .ordered_by_date

    @grouped_expenses = Expense.grouped_expenses(@expenses)
    @total_expenses = Expense.total_expenses(@expenses)

    if @expanded_category.present?
      expanded_expenses = @expenses.where(category: @expanded_category)

      @monthly_expenses = Expense.monthly_expenses(expanded_expenses)
    else
      @monthly_expenses = {}
    end
  end

  def income
    @income_category_filters =
      Array(permitted_params[:income_categories])
        .select { |category| Service::CATEGORIES.include?(category) }

    @income_service_filters =
      Array(permitted_params[:service_ids])
        .filter_map { |id| Integer(id, exception: false) }

    @income_formula_product_filters =
      Array(permitted_params[:formula_product_ids])
        .filter_map { |id| Integer(id, exception: false) }

    @income_care_product_filters =
      Array(permitted_params[:care_product_ids])
        .filter_map { |id| Integer(id, exception: false) }

    summary =
      ::Analytics::IncomeSummary.new(
        user: current_user,
        from: @from,
        to: @to,
        service_categories: @income_category_filters,
        service_ids: @income_service_filters,
        formula_product_ids: @income_formula_product_filters,
        care_product_ids: @income_care_product_filters
      )

    @grouped_income = summary.grouped_service_income
    @income_service_notes = summary.service_notes

    @formula_income = summary.formula_income
    @care_products_income = summary.care_products_income

    @formula_color_income = summary.formula_color_income
    @oxidant_income = summary.oxidant_income
    @care_product_income = summary.care_product_income

    @total_income = summary.total_income

    @income_filter_colors = summary.available_formula_colors
    @income_filter_color_brands = summary.available_formula_color_brands

    @income_filter_oxidants = summary.available_oxidants
    @income_filter_oxidant_brands = summary.available_oxidant_brands

    @income_filter_care_products = summary.available_care_products
    @income_filter_care_brands = summary.available_care_product_brands
    @income_filter_care_categories = summary.available_care_product_categories

    @expanded_income_category =
      if @grouped_income.key?(permitted_params[:expanded])
        permitted_params[:expanded]
      end

    @monthly_income = @expanded_income_category.present? ? summary.monthly_income(@expanded_income_category) : {}

    @income_filter_services = current_user.services.appointment_services.ordered_for_filter
  end

  def balance
    summary = ::Analytics::FinancialSummary.new(user: current_user, from: @from, to: @to)

    @service_income = summary.service_income
    @formula_income = summary.formula_income
    @care_products_income = summary.care_products_income

    @manual_expenses = summary.manual_expenses
    @care_products_cost = summary.care_products_cost

    @total_income = summary.total_income
    @total_expenses = summary.total_expenses
    @balance = summary.balance
  end

  private

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
    case action_name
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
      current_user.expenses.maximum(:spent_on)
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

  def permitted_params
    params.permit(
      :from,
      :to,
      :all_time,
      :expanded,
      :category,
      :service_type,
      :subtype,
      :locale,
      categories: [],
      income_categories: [],
      service_ids: [],
      formula_product_ids: [],
      care_product_ids: []
    )
  end
end

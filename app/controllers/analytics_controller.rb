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
      if @category_filters.include?(permitted_params[:expanded])
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
      expanded_expenses =
        @expenses.where(category: @expanded_category)

      @monthly_expenses =
        Expense.monthly_expenses(expanded_expenses)
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

    @services =
      Service
        .income_for_user_between(current_user, @from, @to)
        .for_user(current_user)
        .apply_income_selection_filters(
          categories: @income_category_filters,
          service_ids: @income_service_filters
        )
        .ordered_income

    @grouped_income = Service.grouped_income_by_category(@services)
    @total_income = @services.sum(:price)

    @expanded_income_category =
      if @grouped_income.key?(permitted_params[:expanded])
        permitted_params[:expanded]
      end

    if @expanded_income_category.present?
      expanded_services =
        @services.where(category: @expanded_income_category)

      @monthly_income =
        Service.monthly_income(expanded_services)
    else
      @monthly_income = {}
    end

    @income_filter_services =
      current_user.services
        .appointment_services
        .ordered_for_filter
  end

  def balance
    @total_income =
      Service
        .income_for_user_between(current_user, @from, @to)
        .sum(:price)

    @total_expenses =
      current_user.expenses
        .where(spent_on: @from..@to)
        .sum(:amount)

    @balance = @total_income - @total_expenses
  end

  private

  def set_period
    @all_time = permitted_params[:all_time] == "1"

    if @all_time
      @from, @to = all_time_period
      return
    end

    from =
      parse_date(permitted_params[:from]) ||
      Date.current.beginning_of_month

    to =
      parse_date(permitted_params[:to]) ||
      Date.current

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
      dates =
        current_user.appointments
          .where.not(appointment_date: nil)

      [
        dates.minimum(:appointment_date) || Date.current,
        dates.maximum(:appointment_date) || Date.current
      ]

    else
      [ Date.current, Date.current ]
    end
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
      service_ids: []
    )
  end
end

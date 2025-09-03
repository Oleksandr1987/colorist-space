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
    @service_type_filter = params[:service_type]
    @category_filter = params[:category]
    @subtype_filter = params[:subtype]

    @services = Service
      .joins(:appointments)
      .where(appointments: { user_id: current_user.id, appointment_date: @from..@to })

    @services = @services.where(service_type: @service_type_filter) if @service_type_filter.present?
    @services = @services.where(category: @category_filter) if @category_filter.present? && @service_type_filter == "service"
    @services = @services.where(subtype: @subtype_filter) if @subtype_filter.present? && @service_type_filter == "service"

    @total_income = @services.sum(:price)

    if @service_type_filter.present?
      if @service_type_filter == 'service'
        @grouped_income = @services.group(:subtype).sum(:price)
      else
        @grouped_income = @services.group(:name).sum(:price)
      end
    else
      @grouped_income = @services.group(:service_type).sum(:price)
    end

    @monthly_income_grouped = @services
      .select("appointments.appointment_date AS date, services.*")
      .order("appointments.appointment_date DESC")
      .group_by { |s| s.service_type }
      .transform_values do |group|
        group.group_by { |s| Date.parse(s.date.to_s).strftime('%B %Y') }
      end
  end

  def balance
    @total_income = Service.income_total_for_user_between(current_user, @from, @to)
    @total_expenses = current_user.expenses.where(spent_on: @from..@to).sum(:amount)
    @balance = @total_income - @total_expenses
  end

  private

  def set_period
    from = (params[:from].presence || Date.today.beginning_of_month).to_date
    to = (params[:to].presence || Date.today).to_date
    @from = [ from, to ].min
    @to = [ from, to ].max
  rescue ArgumentError
    @from = Date.today.beginning_of_month
    @to = Date.today
  end
end

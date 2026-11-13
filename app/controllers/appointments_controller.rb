class AppointmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_appointment, only: %i[show edit update destroy]
  before_action :normalize_time_params, only: %i[create update]

  auto_authorize :appointment, only: %i[new create edit update destroy show]

  after_action :verify_authorized, except: %i[all calendar by_date free_slots check_working_hours filter_options]

  def new
    @appointment = current_user.appointments.build

    if params[:client_id].present?
      client = current_user.clients.find_by(id: params[:client_id])
      if client
        @appointment.client = client
        @appointment.client_name = client.full_name if @appointment.respond_to?(:client_name)
      end
    end

    @appointment.appointment_time = params[:time] if params[:time]

    if params[:date].present?
      picked_date = Date.parse(params[:date]) rescue Date.today
      @appointment.appointment_date = [ picked_date, Date.today ].max
    else
      @appointment.appointment_date = Date.today
    end
  end

  def create
    appointment_data = params.require(:appointment)

    @appointment = current_user.appointments.build(appointment_params.except(:service_ids))

    assign_client_fields(appointment_data)

    if @appointment.errors.any?
      render :new, status: :unprocessable_content
      return
    end

    service_ids = Array(appointment_data[:service_ids]).compact_blank.map(&:to_i)

    Appointment.transaction do
      @appointment.client = resolve_appointment_client!(appointment_data)
      @appointment.save!
      @appointment.sync_services_with_prices!(service_ids)
    end

    redirect_to @appointment, notice: t("appointments.messages.created")
  rescue ActiveRecord::RecordInvalid => error
    handle_client_error(error)
    render :new, status: :unprocessable_content
  end

  def edit; end

  def update
    appointment_data = params.require(:appointment)

    @appointment.assign_attributes(appointment_params.except(:service_ids))

    assign_client_fields(appointment_data)

    if @appointment.errors.any?
      render :edit, status: :unprocessable_content
      return
    end

    service_ids = Array(appointment_data[:service_ids]).compact_blank.map(&:to_i) if appointment_data.key?(:service_ids)

    Appointment.transaction do
      @appointment.client = resolve_appointment_client!(appointment_data)
      @appointment.save!
      @appointment.sync_services_with_prices!(service_ids) if service_ids
    end

    redirect_to @appointment, notice: t("appointments.messages.updated")
  rescue ActiveRecord::RecordInvalid => error
    handle_client_error(error)
    render :edit, status: :unprocessable_content
  end

  def destroy
    Appointments::Destroy.new(appointment: @appointment).call

    redirect_to calendar_appointments_path, notice: t("appointments.messages.deleted")
  end

  def all
    base_scope = current_user.appointments

    @period_first_date, @period_last_date = Appointment.date_bounds(base_scope)

    @all_time = params[:all_time] == "1"

    @from_date = parse_filter_date(params[:from])
    @to_date = parse_filter_date(params[:to])

    if @all_time
      @from_date = @period_first_date
      @to_date = @period_last_date
    end

    filtered_scope = base_scope.search(params[:query]).for_categories(params[:categories]).for_services(params[:service_ids]).distinct

    @stats = Appointment.statistics(filtered_scope, year: Date.current.year, month: Date.current.month)

    @appointments = Appointment.filtered(
      base_scope.with_client,
      query: params[:query],
      categories: params[:categories],
      service_ids: params[:service_ids],
      year: params[:year],
      month: params[:month],
      from_date: @from_date,
      to_date: @to_date,
      all_time: @all_time
    )

    @appointments_by_month = Appointment.grouped_by_month(@appointments)

    @available_categories = current_user.services.categories
    @available_services = current_user.services.for_filter(nil)
  end

  def calendar
    @dates_with_appointments = current_user.appointments.pluck(:appointment_date).map { |d| d.to_date.to_s }
  end

  def check_working_hours
    date = Date.iso8601(params.require(:date))

    result = Appointments::WorkingHoursCheck.new(
      user: current_user,
      date: date,
      start_time: params[:start_time],
      end_time: params[:end_time]
    ).call

    render json: result
  rescue ArgumentError, ActionController::ParameterMissing
    render json: { status: "invalid_date" }, status: :unprocessable_content
  end

  def filter_options
    from_date = parse_filter_date(params[:from])
    to_date = parse_filter_date(params[:to])

    scope = current_user.appointments

    unless params[:all_time] == "1"
      if params[:year].present?
        scope = if params[:month].present?
          scope.for_month(params[:year], params[:month])
        else
          scope.for_year(params[:year])
        end
      else
        scope = scope.for_period(from_date, to_date)
      end
    end

    services = Appointment.available_filter_services(scope, user: current_user).to_a

    render json: {
      categories: services.map(&:category).compact.uniq,
      services: services.map do |service|
        {
          id: service.id,
          category: service.category,
          name: service.subtype
        }
      end
    }
  end

  def by_date
    date = params[:date].presence&.to_date || Date.today

    @appointments = current_user.appointments.includes(:client, :service_note).by_date(date).order(:appointment_time)

    render json: @appointments.map(&:as_calendar_json)
  end

  def free_slots
    date = params[:date].presence&.to_date || Date.current

    return render json: [] if date < Date.current

    ranges = Appointment.available_time_ranges(current_user, date)

    render json: ranges.map { |range|
      {
        start: range[:start].strftime("%H:%M"),
        end: range[:end].strftime("%H:%M")
      }
    }
  end

  private

  def set_appointment
    @appointment = current_user.appointments.find(params[:id])
  end

  def normalize_time_params
    return unless params[:appointment]

    %i[appointment_time end_time].each do |field|
      next unless params[:appointment][field]

      params[:appointment][field] = Time.zone.parse(params[:appointment][field])
    end
  end

  def assign_client_fields(data)
    @appointment.client_name = data[:client_name].to_s.strip
    @appointment.phone = PhoneValidator.normalize(data[:phone])

    if @appointment.client_name.blank?
      @appointment.errors.add(:client_name, :blank)
    end

    raw_digits = data[:phone].to_s.gsub(/\D/, "")

    if raw_digits.length <= 3
      @appointment.errors.add(:phone, :blank)
    end
  end

  def resolve_appointment_client!(data)
    client_id = data[:client_id].presence

    if client_id
      client = current_user.clients.find_by(id: client_id)

      unless client
        @appointment.errors.add(:client_name, :invalid)
        raise ActiveRecord::RecordInvalid, @appointment
      end

      @appointment.client_name = client.full_name
      return client
    end

    first_name, last_name = @appointment.client_name.split(/\s+/, 2)

    normalized_phone = @appointment.phone
    phone_owner = current_user.clients.find_by(phone: normalized_phone)

    phone_owner ||= current_user.clients
      .joins(:client_phones)
      .find_by(client_phones: { phone: normalized_phone })

    if phone_owner
      requested_name = Client.normalized_full_name(first_name, last_name)

      if phone_owner.normalized_name != requested_name
        @appointment.errors.add(:phone, :taken)
        raise ActiveRecord::RecordInvalid, @appointment
      end

      phone_owner.restore! if phone_owner.archived?
      return phone_owner
    end

    normalized_name = Client.normalized_full_name(first_name, last_name)
    existing_client = current_user.clients.find_by(normalized_name: normalized_name)

    if existing_client
      existing_client.restore! if existing_client.archived?
      return existing_client
    end

    current_user.clients.create!(first_name: first_name, last_name: last_name.to_s, phone: normalized_phone)
  end

  def handle_client_error(error)
    return if error.record == @appointment

    if error.record.is_a?(Client)
      error.record.errors.each do |client_error|
        attribute = client_error.attribute == :phone ? :phone : :client_name
        @appointment.errors.add(attribute, client_error.message)
      end
    end

    if @appointment.errors.empty?
      @appointment.errors.add(:base, error.message)
    end
  end

  def parse_filter_date(value)
    return if value.blank?

    Date.strptime(value, "%d.%m.%Y")
  rescue Date::Error
    nil
  end

  def appointment_params
    params.require(:appointment).permit(
      :appointment_date,
      :appointment_time,
      :end_time,
      :notes,
      service_ids: []
    )
  end
end

class AppointmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_appointment, only: %i[show edit update destroy]
  before_action :normalize_time_params, only: %i[create update]

  auto_authorize :appointment, only: %i[new create edit update destroy show]
  after_action :verify_authorized, except: %i[all calendar by_date free_slots]

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

    service_ids =
      Array(appointment_data[:service_ids])
        .compact_blank
        .map!(&:to_i)

    client = Client.resolve_for_appointment(
      user: current_user,
      full_name: appointment_data[:client_name],
      phone: appointment_data[:phone]
    )

    @appointment = current_user.appointments.build(
      appointment_params.except(:service_ids)
    )

    @appointment.client = client
    @appointment.service_ids = service_ids if appointment_data.key?(:service_ids)

    if @appointment.save
      redirect_to @appointment
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    appointment_data = params.require(:appointment)

    new_name  = appointment_data[:client_name].to_s.strip
    new_phone = PhoneValidator.normalize(appointment_data[:phone])

    current_name  = @appointment.client.full_name
    current_phone = @appointment.client.phone

    if new_name != current_name || new_phone != current_phone
      @appointment.client = Client.resolve_for_appointment(
        user: current_user,
        full_name: new_name,
        phone: new_phone
      )
    end

    if appointment_data.key?(:service_ids)
      service_ids = Array(appointment_data[:service_ids])
        .compact_blank
        .map!(&:to_i)

      @appointment.service_ids = service_ids
    end

    if @appointment.update(appointment_params.except(:service_ids))
      redirect_to @appointment,
        notice: "Appointment was successfully updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @appointment.destroy
    redirect_to calendar_appointments_path, notice: "Appointment was successfully deleted."
  end

  def all
    base_scope =
      current_user.appointments
                  .with_client

    @appointments =
      base_scope
        .search(params[:query])
        .for_year(params[:year])
        .for_month(
          params[:year].presence || Date.current.year,
          params[:month]
        )
        .for_categories(params[:categories])
        .for_services(params[:service_ids])
        .distinct
        .ordered

    @appointments_by_month =
      Appointment.grouped_by_month(@appointments)

    @stats =
      Appointment.statistics(base_scope)

    @available_years =
      Appointment.available_years(base_scope)

    @available_categories =
      current_user.services.categories

    @available_services =
      current_user.services.for_filter
  end

  def calendar
    @dates_with_appointments =
      current_user.appointments
                  .pluck(:appointment_date)
                  .map { |d| d.to_date.to_s }
  end

  def by_date
    date = params[:date].presence&.to_date || Date.today

    @appointments = current_user.appointments
      .includes(:client,  :service_note)
      .by_date(date)
      .order(:appointment_time)

    render json: @appointments.map(&:as_calendar_json)
  end

  def free_slots
    date = params[:date].presence&.to_date || Date.today

    return render json: [] if date < Date.today

    slots = Appointment.available_slots(current_user, date)

    render json: slots.map { |slot|
      {
        start: slot[:start].strftime("%H:%M"),
        end: slot[:end].strftime("%H:%M")
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

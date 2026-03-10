class AppointmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_appointment, only: %i[show edit update destroy]
  before_action :normalize_time_params, only: %i[create update]

  auto_authorize :appointment, only: %i[new create edit update destroy show]
  after_action :verify_authorized, except: %i[index history calendar by_date free_slots]

  def index
    @future_appointments = current_user.appointments.future.includes(:client)
    @appointments_by_month = Appointment.grouped_by_month(@future_appointments)
  end

  def history
    @past_appointments = current_user.appointments.past.includes(:client)
    @appointments_by_month = Appointment.grouped_by_month(@past_appointments).reverse_each.to_h
  end

  def new
    @appointment = current_user.appointments.build

    if params[:client_id]
      client = current_user.clients.find_by(id: params[:client_id])
      @appointment.client = client if client
    end

    @appointment.appointment_time = params[:time] if params[:time]
    @appointment.appointment_date = params[:date] if params[:date]
  end

  def create
    client = Client.find_or_create_by_full_name(
      user: current_user,
      full_name: params[:appointment][:client_name],
      phone: params[:appointment][:phone]
    )

    @appointment = current_user.appointments.build(appointment_params.except(:service_ids))
    @appointment.client = client
    @appointment.services = Service.where(id: params[:appointment][:service_ids])

    if @appointment.save
      redirect_to @appointment
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    client = Client.find_or_create_by_full_name(
      user: current_user,
      full_name: params[:appointment][:client_name],
      phone: params[:appointment][:phone]
    )

    @appointment.client = client

    if params[:appointment][:service_ids]
      @appointment.services = Service.where(id: params[:appointment][:service_ids])
    end

    if @appointment.update(appointment_params.except(:service_ids))
      redirect_to @appointment, notice: "Appointment was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @appointment.destroy
    redirect_to appointments_path, notice: "Appointment was successfully deleted."
  end

  def calendar; end

  def by_date
    date = params[:date]&.to_date || Date.today

    @appointments = current_user.appointments
      .includes(:client)
      .by_date(date)
      .order(:appointment_time)

    render json: @appointments.map(&:as_calendar_json)
  end

  def free_slots
    date = params[:date].to_date

    slots = Appointment.available_slots(current_user, date)

    Rails.logger.debug "----- JSON SLOTS -----"
  slots.each do |s|
    Rails.logger.debug "slot json start: #{s[:start]}"
  end
    render json: slots.map {
      |slot|
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

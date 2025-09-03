class AppointmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_appointment, only: %i[show edit update destroy]

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
    client_name = params[:appointment][:client_name].strip
    client_phone = params[:appointment][:phone]

    client = current_user.clients.find_by("CONCAT(first_name, ' ', last_name) = ?", client_name)

    if client.nil?
      first_name, last_name = client_name.split(" ", 2)
      client = current_user.clients.create(
        first_name: first_name,
        last_name: last_name || "",
        phone: client_phone
      )
    end

    @appointment = current_user.appointments.build(appointment_params)
    @appointment.client = client

    if @appointment.save
      @appointment.update(service_name: @appointment.combined_service_name)

      redirect_to @appointment, notice: 'Appointment was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    client_name = params[:appointment][:client_name].strip
    client_phone = params[:appointment][:phone]

    client = current_user.clients.find_by("CONCAT(first_name, ' ', last_name) = ?", client_name)

    if client.nil?
      first_name, last_name = client_name.split(" ", 2)
      client = current_user.clients.create(
        first_name: first_name,
        last_name: last_name || "",
        phone: client_phone
      )
    end

    @appointment.client = client

    if @appointment.update(appointment_params)
      @appointment.reload
      @appointment.update_column(:service_name, @appointment.combined_service_name)
      redirect_to @appointment, notice: 'Appointment was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def edit
    # end_time already assigned — just pass to form
  end

  def destroy
    @appointment.destroy
    redirect_to appointments_path, notice: 'Appointment was successfully deleted.'
  end

  def calendar; end

  def by_date
    date = params[:date]&.to_date || Date.today

    @appointments = current_user.appointments
      .includes(:client, :services)
      .where(appointment_date: date)
      .order(:appointment_time)

    render json: @appointments.map { |a|
      start_time = a.appointment_time.strftime('%H:%M')
      end_time = a.end_time.strftime('%H:%M') if a.end_time.present?

      {
        id: a.id,
        client_name: a.client.full_name,
        service: a.combined_service_name,
        phone: a.client.phone,
        start: "#{a.appointment_date}T#{start_time}",
        end: "#{a.appointment_date}T#{end_time}",
        appointment_time: start_time
      }
    }
  end

  def free_slots
    date = params[:date].to_date
    slot_rules = current_user.slot_rules.select { |rule| rule.active_on?(date) }
    slots = slot_rules.flat_map { |rule| rule.slots_for(date, 5) }
    appointments = current_user.appointments.where(appointment_date: date)

    slots.reject! do |slot|
      slot_start = slot[:start].to_time
      slot_end = slot[:end].to_time

      appointments.any? do |app|
        appointment_start = app.appointment_time.in_time_zone.change(year: date.year, month: date.month, day: date.day)
        appointment_end = app.end_time.in_time_zone.change(year: date.year, month: date.month, day: date.day)

        slot_start < appointment_end && slot_end > appointment_start
      end
    end

    render json: slots.map { |slot|
      {
        start: slot[:start].iso8601,
        end: slot[:end].iso8601
      }
    }
  end

  private

  def set_appointment
    @appointment = current_user.appointments.find(params[:id])
  end

  def appointment_params
    params.require(:appointment).permit(
      :service_name, :appointment_date,
      :appointment_time, :notes,
      :end_time, service_ids: []
    )
  end
end

class ServiceNotesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_client
  before_action :set_service_note, only: %i[show edit update destroy delete_photo]

  def show; end

  def new
    @appointment = current_user.appointments.find(params[:appointment_id])

    @service_note = @client.service_notes.build(
      user: current_user,
      appointment: @appointment
    )

    @service_note.haircut_steps.build

    @selected_service_ids = @appointment.service_ids
    @preparations = current_user.services.where(service_type: "preparation")
  end

  def create
    service_ids = params[:service_note][:service_ids]&.uniq

    @service_note = @client.service_notes.build(
      service_note_params
        .except(:photos)
        .merge(
          user: current_user,
          care_products: parse_care_products
        )
    )
    # :nocov:
    if params[:appointment_id].present?
      # :nocov:
      @service_note.appointment = Appointment.find(params[:appointment_id])
    end

    if service_ids.present?
      @service_note.service_ids = service_ids
    # :nocov:
    elsif @service_note.appointment.present?
      # :nocov:
      @service_note.service_ids = @service_note.appointment.service_ids
    end

    if @service_note.save
      attach_photos

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to edit_client_service_note_path(@client, @service_note) }
      end
    else
      @appointment = @service_note.appointment
      @selected_service_ids = service_ids || []
      @preparations = current_user.services.where(service_type: "preparation")

      render :new, status: :unprocessable_content
    end
  end

  def edit
    @appointment = @service_note.appointment

    @selected_service_ids = @service_note.service_ids
    @service_note.haircut_steps.build if @service_note.haircut_steps.empty?
    @preparations = current_user.services.where(service_type: "preparation")
  end

  def update
    service_ids = params[:service_note][:service_ids]&.uniq || []
    care_products = parse_care_products

    if @service_note.update(
        service_note_params
         .except(:photos)
         .merge(
           service_ids: service_ids,
           care_products: care_products
          )
        )
      attach_photos

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to edit_client_service_note_path(@client, @service_note) }
      end
    else
      @appointment = @service_note.appointment
      @selected_service_ids = service_ids
      @preparations = current_user.services.where(service_type: "preparation")

      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @service_note.destroy
    redirect_to client_path(@client), notice: "Service note deleted"
  end

  def delete_photo
    photo = @service_note.photos.find(params[:photo_id])
    photo.purge

    head :ok
  end

  # :nocov:
  def add_ingredient
    @service_note = @client.service_notes.find(params[:id])

    step_index = params[:step_index]

    ingredient = FormulaIngredient.new

    render turbo_stream: turbo_stream.append(
      "ingredients_step_#{step_index}",
      partial: "service_notes/formula_ingredient_fields",
      locals: {
        ingredient: ingredient,
        step_index: step_index
      }
    )
  end
  # :nocov:

  private

  def set_client
    @client = current_user.clients.find(params[:client_id])
  end

  def set_service_note
    @service_note = @client.service_notes.find(params[:id])
  end

  def service_note_params
    params.require(:service_note).permit(
      :service_type, :notes, :price,
      :care_products,
      photos: [],
      service_ids: [],
      haircut_steps_attributes: [
        :id, :zone, :instrument,
        :parting, :elevation,
        :cut_type, :notes,
        :_destroy
      ],
      formula_steps_attributes: [
        :id, :section, :oxidant, :time, :_destroy,
        formula_ingredients_attributes: {}
      ]
    )
  end

  def parse_care_products
    value = params.dig(:service_note, :care_products)

    return [] if value.blank?

    JSON.parse(value)
  rescue JSON::ParserError
    []
  end

  # :nocov:
  def attach_photos
    return unless params[:service_note][:photos].present?

    @service_note.photos.attach(params[:service_note][:photos])
  end
  # :nocov:
end

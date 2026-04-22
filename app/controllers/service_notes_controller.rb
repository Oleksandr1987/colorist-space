class ServiceNotesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_client
  before_action :set_service_note, only: %i[show edit update destroy delete_photo]

  def show; end

  def new
    @service_note = @client.service_notes.build(user: current_user)

    @appointment = Appointment.find_by(id: params[:appointment_id])
  end

  def create
    @service_note = @client.service_notes.build(
      service_note_params.except(:photos).merge(user: current_user)
    )

    if @service_note.save
      attach_photos

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to edit_client_service_note_path(@client, @service_note) }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :new, status: :unprocessable_entity }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit; end

  def update
    if @service_note.update(service_note_params.except(:photos))
      attach_photos

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to edit_client_service_note_path(@client, @service_note) }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :edit, status: :unprocessable_entity }
        format.html { render :edit, status: :unprocessable_entity }
      end
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
      photos: [],
      formula_steps_attributes: [
        :id, :section, :oxidant, :time, :_destroy,
        formula_ingredients_attributes: {}
      ]
    )
  end

  def attach_photos
    return unless params[:service_note][:photos].present?

    @service_note.photos.attach(params[:service_note][:photos])
  end
end

class ServiceNotesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_client
  before_action :set_service_note, only: %i[show edit update destroy]

  def show; end

  def new
    @service_note = @client.service_notes.build(user: current_user)
    step = @service_note.formula_steps.build
    step.formula_ingredients.build
  end

  def create
    @service_note = @client.service_notes.build(service_note_params.merge(user: current_user))
    if @service_note.save
      redirect_to client_service_note_path(@client, @service_note), notice: "Service note created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @service_note.update(service_note_params)
      redirect_to client_service_note_path(@client, @service_note), notice: "Service note updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @service_note.destroy
    redirect_to client_path(@client), notice: "Service note deleted"
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
      formula_steps_attributes: [
        :id, :section, :oxidant, :time, :_destroy,
        formula_ingredients_attributes: [:id, :shade, :brand, :amount, :_destroy]
      ]
    )
  end
end

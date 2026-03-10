class FormulaStepsController < ApplicationController
  before_action :set_client
  before_action :set_service_note
  before_action :set_formula_step, only: [ :update, :destroy, :clear_oxidant, :clear_time ]

  def create
    @formula_step = @service_note.formula_steps.build(formula_step_params)
    if @formula_step.save
      redirect_to client_service_note_path(@client, @service_note), notice: "Step saved"
    else
      render "service_notes/show", status: :unprocessable_entity
    end
  end

  def update
    if @formula_step.update(formula_step_params)
      redirect_to client_service_note_path(@client, @service_note), notice: "Step updated"
    else
      render "service_notes/show", status: :unprocessable_entity
    end
  end

  def destroy
    @formula_step.destroy
    redirect_to client_service_note_path(@client, @service_note), notice: "Step deleted"
  end

  def clear_oxidant
    @formula_step.clear_oxidant!
    respond_with_service_note
  end

  def clear_time
    @formula_step.clear_time!
    respond_with_service_note
  end

  private

  def set_client
    @client = current_user.clients.find(params[:client_id])
  end

  def set_service_note
    @service_note = @client.service_notes.find(params[:service_note_id])
  end

  def set_formula_step
    @formula_step = @service_note.formula_steps.find(params[:id])
  end

  def formula_step_params
    params.require(:formula_step).permit(:section, :oxidant, :time,
      formula_ingredients_attributes: [ :id, :shade, :brand, :amount, :_destroy ])
  end

  def respond_with_service_note
    respond_to do |format|
      format.turbo_stream
      format.html do
        redirect_back fallback_location: client_service_note_path(@client, @service_note)
      end
    end
  end
end

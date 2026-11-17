# frozen_string_literal: true

class FormulaHistoryController < ApplicationController
  PAGE_SIZE = 10

  before_action :authenticate_user!
  before_action :set_client
  before_action :authorize_formula_target!

  def index
    page = [ params.fetch(:page, 1).to_i, 1 ].max
    page = [ page, 10_000 ].min

    notes = @client.service_notes
      .where(user: current_user)
      .joins(:formula_steps)
      .distinct

    notes = notes.where.not(id: @target_note.id) if @target_note

    if params[:search].present?
      search = params[:search].to_s.strip

      if search.match?(/\A\d{2}\.\d{2}\.\d{4}\z/)
        begin
          date = Date.strptime(search, "%d.%m.%Y")
          notes = notes.joins(:appointment)
                       .where(appointments: { appointment_date: date })
        rescue Date::Error
          notes = notes.none
        end
      end
    end

    total = notes.distinct.count(:id)

    notes = notes
      .includes(:appointment, :formula_steps)
      .order(created_at: :desc, id: :desc)
      .limit(PAGE_SIZE)
      .offset((page - 1) * PAGE_SIZE)

    render json: {
      formulas: notes.map { |note| serialize_summary(note) },
      page: page,
      total: total,
      has_more: page * PAGE_SIZE < total
    }
  end

  def show
    note = @client.service_notes
      .where(user: current_user)
      .includes(:appointment, formula_steps: { formula_ingredients: :formula_product })
      .find(params[:service_note_id])

    raise ActiveRecord::RecordNotFound if @target_note && note.id == @target_note.id

    render json: {
      id: note.id,
      date: note.appointment&.appointment_date,
      steps: note.formula_steps.sort_by(&:id).map do |step|
        {
          section: step.section,
          time: step.time,
          oxidant: step.oxidant_data,
          ingredients: step.formula_ingredients.map do |ingredient|
            {
              shade: ingredient.shade,
              brand: ingredient.brand,
              amount: ingredient.amount,
              price: ingredient.price,
              kind: ingredient.kind,
              formula_product_id: ingredient.formula_product_id,
              unit: ingredient.formula_product&.unit || "g"
            }
          end
        }
      end
    }
  end

  private

  def set_client
    @client = current_user.clients.find(params[:client_id])
  end

  def serialize_summary(note)
    steps = note.formula_steps.sort_by(&:id)

    {
      id: note.id,
      date: note.appointment&.appointment_date,
      steps_count: steps.size,
      sections: steps.map(&:section)
    }
  end

  def authorize_formula_target!
    if params[:target_service_note_id].present?
      authorize_existing_target!
    elsif params[:appointment_id].present?
      authorize_new_target!
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def authorize_existing_target!
    @target_note = @client.service_notes
      .where(user: current_user)
      .find(params[:target_service_note_id])

    raise ActiveRecord::RecordNotFound if @target_note.formula_steps.exists?
  end

  def authorize_new_target!
    appointment = current_user.appointments.find(params[:appointment_id])

    raise ActiveRecord::RecordNotFound unless appointment.client_id == @client.id
    raise ActiveRecord::RecordNotFound if appointment.service_note.present?
  end
end

class ServiceNotesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_client
  before_action :set_service_note,
                only: %i[show edit update destroy delete_photo]

  def show; end

  def new
    @appointment = current_user.appointments.find(params[:appointment_id])

    @service_note = @client.service_notes.build(user: current_user, appointment: @appointment)

    @selected_service_ids = @appointment.service_ids
  end

  def create
    service_ids = params[:service_note][:service_ids]&.uniq

    @service_note =
      @client.service_notes.build(
        service_note_params
          .except(:photos)
          .merge(user: current_user, care_products: parse_care_products)
      )

    # :nocov:
    if params[:appointment_id].present?
      # :nocov:
      @service_note.appointment = current_user.appointments.find(params[:appointment_id])
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

        format.html do
          redirect_to edit_client_service_note_path(@client, @service_note)
        end
      end
    else
      @appointment = @service_note.appointment
      @selected_service_ids = service_ids || []

      render :new, status: :unprocessable_content
    end
  end

  def edit
    @appointment = @service_note.appointment

    @selected_service_ids = @service_note.service_ids
  end

  def update
    service_ids =
      if params[:service_note].key?("service_ids")
        Array(params[:service_note][:service_ids])
          .compact_blank
          .uniq
      else
        @service_note.service_ids
      end

    care_products = params[:service_note].key?("care_products") ? parse_care_products : @service_note.care_products

    if @service_note.update(
      service_note_params
        .except(:photos, :service_ids, :care_products)
        .merge(service_ids: service_ids, care_products: care_products)
    )
      attach_photos

      respond_to do |format|
        format.turbo_stream

        format.html do
          redirect_to edit_client_service_note_path(@client, @service_note)
        end
      end
    else
      @appointment = @service_note.appointment
      @selected_service_ids = service_ids

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

  private

  def set_client
    @client =current_user.clients.find(params[:client_id])
  end

  def set_service_note
    @service_note = @client.service_notes.find(params[:id])
  end

  def service_note_params
    params.require(:service_note).permit(
      :service_type,
      :notes,
      :price,
      :care_products,
      photos: [],
      service_ids: [],
      haircut_steps_attributes: [
        :id,
        :zone,
        :instrument,
        :parting,
        :elevation,
        :cut_type,
        :notes,
        :_destroy
      ],
      formula_steps_attributes: [
        :id,
        :section,
        :oxidant,
        :time,
        :_destroy,
        formula_ingredients_attributes: {}
      ]
    )
  end

  def parse_care_products
    value =params.dig(:service_note, :care_products)

    return [] if value.blank?

    items = JSON.parse(value)

    existing_products =
      Array(@service_note&.care_products).index_by do |item|
        item["care_product_id"].to_s
      end

    items.filter_map do |item|
      product = current_user.care_products.find_by(id: item["care_product_id"])

      next unless product

      existing_item = existing_products[product.id.to_s]

      purchase_price = existing_item&.key?("purchase_price") ? existing_item["purchase_price"] : product.purchase_price

      {
        "care_product_id" => product.id,
        "name" => (
          item["name"].presence ||
          product.display_name
        ),
        "price" => item["price"].to_f,
        "purchase_price" => purchase_price.to_f,
        "qty" => item["qty"].to_i
      }
    end
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

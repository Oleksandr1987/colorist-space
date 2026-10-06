class ClientsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_client, only: %i[show edit update destroy delete_photo delete_all_photos]

  auto_authorize :client, only: %i[show new create edit update destroy delete_photo delete_all_photos]
  after_action :verify_authorized, only: %i[show new create edit update destroy delete_photo delete_all_photos]

  def index
    @clients = current_user.clients.active.with_phones.alphabetical
  end

  def search
    @clients = current_user.clients.active.with_phones.search_by_name(params[:query]).alphabetical

    render :index
  end

  def show
    @past_appointments = @client.appointments.past.order(appointment_date: :desc)
    @future_appointments = @client.appointments.future.order(:appointment_date)
  end

  def new
    @client = current_user.clients.build
  end

  def create
    @client = current_user.clients.build(client_params)

    if @client.save
      redirect_to @client, notice: t("clients.messages.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    @client.attach_photos(client_params[:photos])

    if @client.update(client_params.except(:photos))
      redirect_to @client, notice: t("clients.messages.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @client.archive!

    redirect_to clients_path, notice: t("clients.messages.archived")
  end

  def autocomplete
    clients = current_user.clients.active.search_by_name(params[:term])

    render json: clients.select(:id, :first_name, :last_name, :phone)
  end

  def delete_photo
    @client.delete_photo(params[:photo_id])

    redirect_to @client, notice: t("clients.messages.photo_deleted")
  end

  def delete_all_photos
    @client.delete_all_photos

    redirect_to @client, notice: t("clients.messages.all_photos_deleted")
  end

  def make_primary
    @client = current_user.clients.find(params[:id])

    @client.make_primary!(params[:phone])

    @client = current_user.clients.includes(:client_phones).find(params[:id])

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  def set_client
    @client = current_user.clients.active.find(params[:id])
  end

  def client_params
    params.require(:client).permit(
      :first_name,
      :last_name,
      :phone,
      :birthday,
      :hair_type,
      :hair_length,
      :hair_structure,
      :hair_density,
      :scalp_condition,
      :note,
      photos: [],
      client_phones_attributes: %i[id phone _destroy]
    )
  end
end

class ClientsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_client, only: %i[show edit update destroy delete_photo delete_all_photos]

  auto_authorize :client, only: %i[show new create edit update destroy delete_photo delete_all_photos]
  after_action :verify_authorized, only: %i[show new create edit update destroy delete_photo delete_all_photos]

  def index
    @clients = current_user.clients.alphabetical
  end

  def search
    @clients = current_user.clients.search_by_name(params[:query])
    render :index
  end

  def show
  end

  def new
    @client = current_user.clients.build
  end

  def create
    @client = current_user.clients.build(client_params)

    if @client.save
      redirect_to edit_client_path(@client),
        notice: "Client was created. Please add hair details."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @client.attach_photos(client_params[:photos])

    if @client.update(client_params.except(:photos))
      redirect_to @client, notice: "Client was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @client.destroy

    redirect_to clients_path,
      notice: "Client was successfully deleted."
  end

  def autocomplete
    clients = current_user.clients.search_by_name(params[:term])

    render json: clients.select(
      :id,
      :first_name,
      :last_name,
      :phone
    )
  end

  def delete_photo
    @client.delete_photo(params[:photo_id])

    redirect_to @client,
      notice: "Photo deleted."
  end

  def delete_all_photos
    @client.delete_all_photos

    redirect_to @client,
      notice: "All photos deleted."
  end

  private

  def set_client
    @client = current_user.clients.find(params[:id])
  end

  def client_params
    params.require(:client).permit(
      :first_name,
      :last_name,
      :phone,
      :birthdate,
      :hair_type,
      :hair_length,
      :hair_structure,
      :hair_density,
      :scalp_condition,
      :note,
      photos: []
    )
  end
end

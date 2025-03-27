class ClientsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_client, only: %i[show edit update destroy]

  def index
    @clients = current_user.clients.alphabetical
  end

  def search
    @clients = current_user.clients.search(params[:query])
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
      redirect_to edit_client_path(@client), notice: 'Client was created. Please add hair details.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if client_params[:photos].present?
      @client.photos.attach(client_params[:photos])
    end

    if @client.update(client_params.except(:photos))
      redirect_to @client, notice: 'Client was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @client.destroy
    redirect_to clients_path, notice: 'Client was successfully deleted.'
  end

  def import_contacts
    contacts = params[:contacts]

    if contacts.present?
      contacts.each do |contact|
        current_user.clients.create(
          first_name: contact[:first_name],
          last_name: contact[:last_name],
          phone: contact[:phone]
        )
      end
      render json: { message: 'Contacts imported successfully' }
    else
      render json: { message: 'No contacts to import' }, status: :unprocessable_entity
    end
  end

  private

  def set_client
    @client = current_user.clients.find(params[:id])
  end

  def client_params
    params.require(:client).permit(
      :first_name, :last_name, :phone, :birthdate,
      :hair_type, :hair_length, :hair_structure,
      :hair_density, :scalp_condition, :note, photos: []
    )
  end
end

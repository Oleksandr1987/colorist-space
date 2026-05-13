class ClientsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_client, only: %i[show edit update destroy delete_photo delete_all_photos]

  auto_authorize :client, only: %i[show new create edit update destroy delete_photo delete_all_photos]
  after_action :verify_authorized, only: %i[show new create edit update destroy delete_photo delete_all_photos]

  def index
    @clients = current_user.clients
      .with_phones
      .alphabetical
  end

  def search
    @clients = current_user.clients
      .with_phones
      .search_by_name(params[:query])
      .alphabetical

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
    normalized_phone = PhoneValidator.normalize(client_params[:phone])

    existing_client =
      current_user.clients.find_by(phone: normalized_phone) ||
      Client.joins(:client_phones)
          .where(client_phones: { phone: normalized_phone })
          .find_by(user_id: current_user.id)

    if existing_client
      redirect_to edit_client_path(existing_client),
        alert: "Client with this phone already exists. You can update their info."
      return
    end

    @client = current_user.clients.build(client_params)

    if @client.save
      redirect_to edit_client_path(@client),
        notice: "Client was created. Please add hair details."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    @client.attach_photos(client_params[:photos])

    if @client.update(client_params.except(:photos))
      redirect_to @client, notice: "Client was successfully updated."
    else
      render :edit, status: :unprocessable_content
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

  def make_primary
    @client = current_user.clients.find(params[:id])

    @client.make_primary!(params[:phone])

    head :ok
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
      :hair_type,
      :hair_length,
      :hair_structure,
      :hair_density,
      :scalp_condition,
      :note,
      photos: [],
      client_phones_attributes: [ :id, :phone, :_destroy ]
    )
  end
end

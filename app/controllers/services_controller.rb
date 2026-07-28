class ServicesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_service, only: %i[edit update destroy]

  auto_authorize :service, only: %i[new create edit update destroy]
  after_action :verify_authorized, only: %i[new create edit update destroy]

  def index
  end

  def main
    @categories = Service.categories_for_user(current_user)
  end

  def section
    @category = Service.normalize_category(params[:category])

    @translated_category = t("services.categories.#{@category}", default: @category)

    @services = Service.for_user_and_category(current_user, @category)
  end

  def new
    @service = Service.new(
      service_type: params[:service_type] || "service",
      category: Service.normalize_category(params[:category])
    )
  end

  def create
    attributes = service_params
    attributes[:category] = Service.normalize_category(attributes[:category])

    @service = current_user.services.build(attributes)

    if @service.save
      redirect_to redirect_path_for(@service), notice: "Service created successfully."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    attributes = service_params
    attributes[:category] = Service.normalize_category(attributes[:category])

    if @service.update(attributes)
      redirect_to redirect_path_for(@service), notice: "Service updated successfully."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    service_type = @service.service_type
    category = @service.category
    @service.destroy

    redirect_to redirect_path_for_open(service_type, category), notice: "Service deleted."
  end

  private

  def set_service
    @service = current_user.services.find(params[:id])
  end

  def service_params
    params.require(:service).permit(:name, :price, :category, :subtype, :service_type, :unit)
  end

  def redirect_path_for(service)
    case service.service_type
    when "service"
      section_services_path(category: service.category)
    else
      services_path
    end
  end

  def redirect_path_for_open(service_type, category)
    case service_type
    when "service"
      section_services_path(category: category)
    else
      services_path
    end
  end
end

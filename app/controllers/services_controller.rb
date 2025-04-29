class ServicesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_service, only: %i[edit update destroy]

  def index
    # На /services показуються три кнопки: Services, Preparations, Care Products
  end

  def main
    @categories = current_user.services
                               .where(service_type: "service")
                               .distinct
                               .pluck(:category)
                               .compact
  end

  def section
    @category = params[:category]
    @services = current_user.services
                             .where(service_type: "service", category: @category)
                             .order(:subtype)
  end

  def preparations
    @preparations = current_user.services
                                 .where(service_type: "preparation")
                                 .order(:subtype)
  end

  def care_products
    @care_products = current_user.services
                                  .where(service_type: "care_product")
                                  .order(:subtype)
  end

  def new
    @service = Service.new(service_type: params[:service_type] || "service")
    @service.category = params[:category] if params[:category].present?
  end

  def create
    @service = current_user.services.build(service_params)
    @service.name = @service.subtype

    if @service.save
      redirect_to redirect_path_for(@service), notice: "Service created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @service.update(service_params)
      redirect_to redirect_path_for(@service), notice: "Service updated successfully."
    else
      render :edit, status: :unprocessable_entity
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
      services_section_path(category: service.category)
    when "preparation"
      services_preparations_path
    when "care_product"
      services_care_products_path
    else
      services_path
    end
  end

  def redirect_path_for_open(service_type, category)
    case service_type
    when "service"
      services_section_path(category: category)
    when "preparation"
      services_preparations_path
    when "care_product"
      services_care_products_path
    else
      services_path
    end
  end
end

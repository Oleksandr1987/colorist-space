class ServicesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_service, only: %i[edit update destroy]

  auto_authorize :service, only: %i[new create edit update destroy]
  after_action :verify_authorized, only: %i[new create edit update destroy]

  # СЛОВНИК ДЕФОЛТНИХ КАТЕГОРІЙ
  DEFAULT_CATEGORIES = {
    "haircut"   => I18n.t("services.categories.haircut"),
    "coloring"  => I18n.t("services.categories.coloring"),
    "styling"   => I18n.t("services.categories.styling"),
    "treatment" => I18n.t("services.categories.treatment")
  }.freeze

  def index
  end

  def main
    @categories = current_user.services
      .where(service_type: "service")
      .distinct
      .pluck(:category)
      .compact
  end

  def section
    @category = normalize_category(params[:category])

    @translated_category = DEFAULT_CATEGORIES[@category] || @category

    @services = current_user.services.where(service_type: "service", category: @category).order(:subtype)
  end

  def new
    @service = Service.new(service_type: params[:service_type] || "service")

    if params[:category].present?
      @service.category = normalize_category(params[:category])
    end
  end

  def create
    @service = current_user.services.build(service_params)
    @service.category = normalize_category(@service.category)
    @service.name = @service.subtype

    if @service.save
      redirect_to redirect_path_for(@service), notice: "Service created successfully."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    @service.category = normalize_category(service_params[:category])

    if @service.update(service_params)
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

  def normalize_category(category)
    return "" if category.blank?

    found = DEFAULT_CATEGORIES.find { |k, v| v.casecmp?(category) }
    return found.first if found

    key = category.downcase
    return key if DEFAULT_CATEGORIES.key?(key)
    category
  end

  def translate_category(category)
    return category unless DEFAULT_CATEGORIES.key?(category)

    DEFAULT_CATEGORIES[category]
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

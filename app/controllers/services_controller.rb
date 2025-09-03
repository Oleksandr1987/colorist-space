class ServicesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_service, only: %i[edit update destroy]

  def index
    if params[:category].present?
      @category = params[:category]
      @services = current_user.services.or(Service.where(user_id: nil))
                              .where(category: @category)
                              .order(:subtype)
    else
      @categories = current_user.services.or(Service.where(user_id: nil))
                                 .distinct
                                 .pluck(:category)
                                 .compact
    end
  end

  def new
    @service = Service.new(category: params[:category])
  end

  def create
    @service = current_user.services.build(service_params)
    @service.name = @service.subtype # ← додано

    if @service.save
      redirect_to services_path(category: @service.category), notice: "Service created successfully."
    else
      @category = @service.category.presence

      if @category.present?
        @services = current_user.services.or(Service.where(user_id: nil))
                                .where(category: @category)
                                .order(:subtype)
      end

      @categories = current_user.services.or(Service.where(user_id: nil))
                                 .distinct
                                 .pluck(:category)
                                 .compact

      render :index, status: :unprocessable_entity
    end
  end

  def update
    @service.name = service_params[:subtype] # ← додано
    if @service.update(service_params)
      redirect_to services_path(category: @service.category), notice: "Service updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @service.update(service_params)
      redirect_to services_path(category: @service.category), notice: "Service updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    category = @service.category
    @service.destroy
    redirect_to services_path(category: category), notice: "Service deleted."
  end

  private

  def set_service
    @service = current_user.services.find(params[:id])
  end

  def service_params
    params.require(:service).permit(:name, :price, :category, :subtype)
  end
end

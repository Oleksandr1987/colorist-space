class CareProductsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_care_product, only: %i[show edit update destroy archive restore]

  before_action :set_active_care_product, only: %i[restock create_restock adjust_stock update_stock]

  def index
    @care_product = CareProduct.new if params[:new] == "true"

    @care_products = current_user.care_products.active.order(:name)
  end

  def new
    @care_product =
      current_user.care_products.build
  end

  def create
    @care_product =
      CareProducts::Create.new(user: current_user, attributes: create_care_product_params, purchased_on: purchased_on).call

    respond_to do |format|
      format.html do
        redirect_to care_products_path, notice: "Care product created successfully."
      end

      format.json do
        render json: {
          id: @care_product.id,
          brand: @care_product.brand,
          name: @care_product.name,
          category: @care_product.category,
          sale_price: @care_product.sale_price.to_f,
          incomplete: @care_product.incomplete?
        }
      end
    end
  rescue ActiveRecord::RecordInvalid, ArgumentError => e
    @care_product =
      if e.is_a?(ActiveRecord::RecordInvalid) && e.record.is_a?(CareProduct)
        e.record
      else
        current_user.care_products.build(create_care_product_params)
      end

    @archived_duplicate = @care_product.archived_duplicate

    respond_to do |format|
      format.html do
        render :new, status: :unprocessable_content
      end

      format.json do
        errors =  e.is_a?(ActiveRecord::RecordInvalid) ? e.record.errors.full_messages : [ e.message ]
        render json: { errors: errors }, status: :unprocessable_content
      end
    end
  end

  def show
    @stock_movements =
      @care_product
        .stock_movements
        .includes(:expense, :care_product_sale, service_note: %i[client appointment])
        .order(occurred_on: :desc, created_at: :desc)
  end

  def edit
  end

  def update
    if @care_product.update(update_care_product_params)
      redirect_to care_products_path,
        notice: "Care product updated successfully."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def restock
    @quantity = nil
    @unit_cost = @care_product.purchase_price
    @purchased_on = Date.current
  end

  def create_restock
    @quantity = restock_params[:quantity]
    @unit_cost = restock_params[:unit_cost]
    @purchased_on = parse_date(restock_params[:purchased_on])

    CareProducts::Restock.new(
      user: current_user,
      care_product: @care_product,
      quantity: @quantity,
      unit_cost: @unit_cost,
      purchased_on: @purchased_on
    ).call

    redirect_to care_products_path, notice: t("care_products.restock.success")

  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.message

    render :restock, status: :unprocessable_content
  end

  def adjust_stock
  end

  def update_stock
    CareProducts::AdjustStock.new(
      user: current_user,
      care_product: @care_product,
      quantity: adjustment_params[:quantity],
      reason: adjustment_params[:reason],
      note: adjustment_params[:note],
      occurred_on: parse_date(adjustment_params[:occurred_on])
    ).call

    redirect_to care_products_path, notice: t("care_products.adjustment.success")
  rescue ArgumentError => e
    flash.now[:alert] = e.message
    render :adjust_stock, status: :unprocessable_content
  end

  def archive
    @care_product.archive!

    redirect_to care_products_path, notice: t("care_products.archive.success")
  rescue ActiveRecord::RecordInvalid
    redirect_to care_product_path(@care_product), alert: @care_product.errors.full_messages.to_sentence
  end

  def archived
    @care_products = current_user.care_products.archived
  end

  def restore
    @care_product.restore!

    redirect_to care_product_path(@care_product), notice: t("care_products.restore.success")
  end

  def destroy
    @care_product.soft_delete!

    redirect_to care_products_path, notice: t("care_products.delete.success")
  rescue ActiveRecord::RecordInvalid
    redirect_to care_product_path(@care_product), alert: @care_product.errors.full_messages.to_sentence
  end

  def options
    render json: current_user
      .care_products
      .active
      .order(:brand, :name)
      .map do |product|
        {
          id: product.id,
          brand: product.brand,
          name: product.name,
          category: product.category,
          sale_price: product.sale_price.to_f,
          stock_quantity: product.stock_quantity.to_i
        }
      end
  end

  private

  def set_care_product
    @care_product = current_user.care_products.find(params[:id])
  end

  def set_active_care_product
    @care_product = current_user.care_products.active.find(params[:id])
  end

  def create_care_product_params
    params.require(:care_product).permit(:brand, :name, :category, :purchase_price, :sale_price, :stock_quantity)
  end

  def update_care_product_params
    params.require(:care_product).permit(:brand, :name, :category, :sale_price)
  end

  def restock_params
    params.require(:restock).permit(:quantity, :unit_cost, :purchased_on)
  end

  def adjustment_params
    params.require(:adjustment).permit(:quantity, :reason, :note, :occurred_on)
  end

  def purchased_on
    value = params.dig(:care_product, :purchased_on)

    return Date.current if value.blank?

    Date.iso8601(value)
  rescue Date::Error
    nil
  end

  def parse_date(value)
    return if value.blank?

    Date.iso8601(value)
  rescue Date::Error
    nil
  end
end

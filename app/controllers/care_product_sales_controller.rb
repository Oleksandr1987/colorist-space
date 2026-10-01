# frozen_string_literal: true

class CareProductSalesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_care_product

  def new
    @sale = CareProductSale.new(
      care_product: @care_product,
      quantity: 1,
      unit_price: @care_product.sale_price,
      sold_on: Date.current
    )
  end

  def create
    validate_sold_on!

    @sale = CareProducts::Sell.new(
      user: current_user,
      care_product: @care_product,
      quantity: sale_params[:quantity],
      unit_price: sale_params[:unit_price],
      sold_on: sale_params[:sold_on]
    ).call

    redirect_to care_products_path, notice: t("care_products.sale.success")
  rescue ArgumentError => e
    @sale = CareProductSale.new(sale_params)
    @sale.care_product = @care_product

    flash.now[:alert] = e.message

    render :new, status: :unprocessable_content
  end

  private

  def set_care_product
    @care_product = current_user.care_products.active.find(params[:care_product_id])
  end

  def validate_sold_on!
    sold_on = Date.iso8601(sale_params[:sold_on])

    raise ArgumentError, I18n.t("care_products.errors.sold_on_future") if sold_on > Date.current
  rescue Date::Error
    raise ArgumentError, I18n.t("care_products.errors.sold_on_required")
  end

  def sale_params
    params.require(:care_product_sale).permit(:quantity, :unit_price, :sold_on)
  end
end

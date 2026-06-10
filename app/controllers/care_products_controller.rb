class CareProductsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_care_product,
                only: %i[
                  edit
                  update
                  destroy
                ]

  def index
    @care_product =
      CareProduct.new if params[:new] == "true"

    @care_products =
      current_user.care_products
                  .order(:name)
  end

  def new
    @care_product =
      current_user.care_products.build
  end

  def create
    @care_product =
      current_user.care_products.build(
        care_product_params
      )

    if @care_product.save
      respond_to do |format|
        format.html do
          redirect_to care_products_path,
            notice: "Care product created successfully."
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
    else
      respond_to do |format|
        format.html do
          render :new,
                 status: :unprocessable_content
        end

        format.json do
          render json: {
            errors: @care_product.errors.full_messages
          },
          status: :unprocessable_content
        end
      end
    end
  end

  def edit
  end

  def update
    if @care_product.update(
         care_product_params
       )
      redirect_to care_products_path,
        notice: "Care product updated successfully."
    else
      render :edit,
             status: :unprocessable_content
    end
  end

  def destroy
    @care_product.destroy

    redirect_to care_products_path,
      notice: "Care product deleted."
  end

  private

  def set_care_product
    @care_product =
      current_user.care_products.find(
        params[:id]
      )
  end

  def care_product_params
    params.require(:care_product).permit(
      :brand,
      :name,
      :category,
      :purchase_price,
      :sale_price,
      :stock_quantity
    )
  end
end

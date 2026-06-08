class FormulaProductsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_formula_product,
                only: %i[edit update destroy]

  def index
    @category = params[:category] || "color"

    @formula_products =
      current_user.formula_products
                  .where(category: @category)
                  .order(:brand, :name)
  end

  def new
    @formula_product =
      current_user.formula_products.build(
        category: params[:category]
      )
  end

  def create
    @formula_product =
      current_user.formula_products.build(
        formula_product_params
      )

    if @formula_product.save
      respond_to do |format|
        format.html do
          redirect_to formula_products_path(
            category: @formula_product.category
          )
      end

      format.json do
        render json: {
          id: @formula_product.id,
          brand: @formula_product.brand,
          name: @formula_product.name
        }
      end
    end

    else
      render :new,
             status: :unprocessable_content
    end
  end

  def create_oxidant
    @formula_product =
      current_user.formula_products.create(
        category: "oxidant",
        brand: "Generic",
        name: params[:name],
        price_per_unit: params[:price_per_unit],
        unit: params[:unit] || "ml"
      )

    Rails.logger.info @formula_product.errors.full_messages

    render json: {
      id: @formula_product.id,
      name: @formula_product.name,
      price: @formula_product.price_per_unit,
      unit: @formula_product.unit
    }
  end

  def edit
  end

  def update
    if @formula_product.update(
         formula_product_params
       )
      redirect_to formula_products_path(
        category: @formula_product.category
      )
    else
      render :edit,
             status: :unprocessable_content
    end
  end

  def destroy
    category = @formula_product.category

    @formula_product.destroy

    redirect_to formula_products_path(
      category: category
    )
  end

  private

  def set_formula_product
    @formula_product =
      current_user.formula_products.find(
        params[:id]
      )
  end

  def formula_product_params
    params.require(:formula_product).permit(
      :category,
      :brand,
      :name,
      :unit,
      :price_per_unit
    )
  end
end

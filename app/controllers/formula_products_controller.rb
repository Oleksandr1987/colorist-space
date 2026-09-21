class FormulaProductsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_formula_product, only: %i[edit update destroy]

  def index
    @formula_products = current_user.formula_products.ordered

    @color_brands = FormulaProduct.brands_for(@formula_products, "color")

    @oxidant_brands = FormulaProduct.brands_for(@formula_products, "oxidant")

    @oxidant_percentages = FormulaProduct.oxidant_percentages(@formula_products)
  end

  def new
    @formula_product = current_user.formula_products.build(category: params[:category])
  end

  def create
    @formula_product = current_user.formula_products.build(formula_product_params)

    if @formula_product.save
      respond_to do |format|
        format.html { redirect_to formula_products_path }

        format.json do
          render json: {
            id: @formula_product.id,
            brand: @formula_product.brand,
            unit: @formula_product.unit,
            price_per_unit: @formula_product.price_per_unit
          }
        end
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_content }

        format.json do
          render json: {
            errors: @formula_product.errors.full_messages
          }, status: :unprocessable_content
        end
      end
    end
  end

  def edit
  end

  def update
    if @formula_product.update(formula_product_params)
      redirect_to formula_products_path
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @formula_product.destroy

    redirect_to formula_products_path
  end

  private

  def set_formula_product
    @formula_product = current_user.formula_products.find(params[:id])
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

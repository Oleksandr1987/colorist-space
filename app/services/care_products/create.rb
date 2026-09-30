# frozen_string_literal: true

module CareProducts
  class Create
    attr_reader :user, :attributes, :purchased_on

    def initialize(user:, attributes:, purchased_on:)
      @user = user
      @attributes = attributes
      @purchased_on = purchased_on
    end

    def call
      CareProduct.transaction do
        care_product = user.care_products.create!(attributes)
        expense = create_expense!(care_product)

        create_opening_balance!(care_product, expense)

        care_product
      end
    end

    private

    def create_expense!(care_product)
      return unless care_product.stock_quantity.to_i.positive?
      return if care_product.purchase_price.blank?

      user.expenses.create!(
        category: "care_products",
        amount: expense_amount(care_product),
        spent_on: purchased_on
      )
    end

    def create_opening_balance!(care_product, expense)
      return unless care_product.stock_quantity.to_i.positive?

      user.care_product_stock_movements.create!(
        care_product: care_product,
        expense: expense,
        movement_type: "opening_balance",
        quantity: care_product.stock_quantity,
        unit_cost: care_product.purchase_price,
        occurred_on: purchased_on
      )
    end

    def expense_amount(care_product)
      (care_product.purchase_price.to_d * care_product.stock_quantity.to_i).to_i
    end
  end
end

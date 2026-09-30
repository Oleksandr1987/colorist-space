# frozen_string_literal: true

module CareProducts
  class Restock
    attr_reader :user, :care_product, :quantity, :unit_cost, :purchased_on

    def initialize(user:, care_product:, quantity:, unit_cost:, purchased_on:)
      @user = user
      @care_product = care_product
      @quantity = quantity.to_i
      @unit_cost = unit_cost.to_d
      @purchased_on = purchased_on
    end

    def call
      validate!

      CareProduct.transaction do
        care_product.with_lock do
          old_stock = care_product.stock_quantity.to_i
          old_cost = care_product.purchase_price.to_d
          new_stock = old_stock + quantity
          new_cost = weighted_average_cost(old_stock: old_stock, old_cost: old_cost, new_stock: new_stock)

          expense = user.expenses.create!(category: "care_products", amount: total_cost, spent_on: purchased_on)

          movement = user.care_product_stock_movements.create!(
            care_product: care_product,
            expense: expense,
            movement_type: "purchase",
            quantity: quantity,
            unit_cost: unit_cost,
            stock_after: new_stock,
            occurred_on: purchased_on
          )

          care_product.update!(stock_quantity: new_stock, purchase_price: new_cost)

          movement
        end
      end
    end

    private

    def validate!
      raise ArgumentError, I18n.t("care_products.errors.wrong_user") unless care_product.user_id == user.id
      raise ArgumentError, I18n.t("care_products.errors.quantity_must_be_positive") unless quantity.positive?
      raise ArgumentError, I18n.t("care_products.errors.unit_cost_must_be_non_negative") if unit_cost.negative?
      raise ArgumentError, I18n.t("care_products.errors.unit_cost_must_be_whole_number") unless unit_cost.frac.zero?
      raise ArgumentError, I18n.t("care_products.errors.purchased_on_required") if purchased_on.blank?
      raise ArgumentError, I18n.t("care_products.errors.purchased_on_future") if purchased_on > Date.current
    end

    def total_cost
      (unit_cost * quantity).to_i
    end

    def weighted_average_cost(old_stock:, old_cost:, new_stock:)
      return unit_cost if old_stock.zero?

      ((old_stock * old_cost) + (unit_cost * quantity)) / new_stock
    end
  end
end

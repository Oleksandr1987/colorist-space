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
            occurred_on: purchased_on
          )

          care_product.update!(stock_quantity: new_stock, purchase_price: new_cost)

          movement
        end
      end
    end

    private

    def validate!
      raise ArgumentError, "Care product must belong to user" unless care_product.user_id == user.id
      raise ArgumentError, "Quantity must be greater than zero" unless quantity.positive?
      raise ArgumentError, "Unit cost must be greater than or equal to zero" if unit_cost.negative?
      raise ArgumentError, "Unit cost must be a whole number" unless unit_cost.frac.zero?
      raise ArgumentError, "Purchased on is required" if purchased_on.blank?
      raise ArgumentError, "Purchased on cannot be in the future" if purchased_on > Date.current
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

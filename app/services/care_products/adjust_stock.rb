# frozen_string_literal: true

module CareProducts
  class AdjustStock
    attr_reader :user, :care_product, :quantity, :reason, :note, :occurred_on

    def initialize(user:, care_product:, quantity:, reason:, occurred_on:, note: nil)
      @user = user
      @care_product = care_product
      @quantity = quantity.to_i
      @reason = reason
      @note = note
      @occurred_on = occurred_on
    end

    def call
      validate!

      CareProduct.transaction do
        care_product.with_lock do
          new_stock = care_product.stock_quantity.to_i + quantity

          raise ArgumentError, I18n.t("care_products.errors.adjustment_negative_stock") if new_stock.negative?

          movement = user.care_product_stock_movements.create!(
            care_product: care_product,
            movement_type: "adjustment",
            adjustment_reason: reason,
            quantity: quantity,
            unit_cost: care_product.purchase_price.to_d,
            stock_after: new_stock,
            note: note.presence,
            occurred_on: occurred_on
          )

          care_product.update!(stock_quantity: new_stock)

          movement
        end
      end
    end

    private

    def validate!
      raise ArgumentError, I18n.t("care_products.errors.wrong_user") unless care_product.user_id == user.id
      raise ArgumentError, I18n.t("care_products.errors.adjustment_quantity_required") if quantity.zero?
      raise ArgumentError, I18n.t("care_products.errors.adjustment_date_required") if occurred_on.blank?
      raise ArgumentError, I18n.t("care_products.errors.adjustment_date_future") if occurred_on > Date.current

      unless CareProductStockMovement::ADJUSTMENT_REASONS.include?(reason)
        raise ArgumentError, I18n.t("care_products.errors.adjustment_reason_required")
      end
    end
  end
end

# frozen_string_literal: true

module CareProducts
  class Sell
    attr_reader :user, :care_product, :quantity, :unit_price, :sold_on, :service_note

    def initialize(user:, care_product:, quantity:, unit_price:, sold_on:, service_note: nil)
      @user = user
      @care_product = care_product
      @quantity = quantity.to_i
      @unit_price = unit_price.to_d
      @sold_on = sold_on
      @service_note = service_note
    end

    def call
      validate!

      CareProduct.transaction do
        care_product.with_lock do
          validate_stock!

          new_stock = care_product.stock_quantity.to_i - quantity

          sale = user.care_product_sales.create!(
            care_product: care_product,
            appointment: service_note&.appointment,
            service_note: service_note,
            quantity: quantity,
            unit_price: unit_price,
            unit_cost: care_product.purchase_price.to_d,
            sold_on: sold_on
          )

          movement = user.care_product_stock_movements.create!(
            care_product: care_product,
            appointment: service_note&.appointment,
            service_note: service_note,
            movement_type: "sale",
            quantity: -quantity,
            unit_cost: care_product.purchase_price.to_d,
            stock_after: new_stock,
            occurred_on: sold_on
          )

          sale.update!(stock_movement: movement)
          care_product.update!(stock_quantity: new_stock)

          sale
        end
      end
    end

    private

    def validate!
      raise ArgumentError, I18n.t("care_products.errors.wrong_user") unless care_product.user_id == user.id
      raise ArgumentError, I18n.t("care_products.errors.deleted_product") if care_product.deleted?
      raise ArgumentError, I18n.t("care_products.errors.archived_product") if care_product.archived?
      raise ArgumentError, I18n.t("care_products.errors.quantity_must_be_positive") unless quantity.positive?
      raise ArgumentError, I18n.t("care_products.errors.unit_price_must_be_non_negative") if unit_price.negative?
      raise ArgumentError, I18n.t("care_products.errors.sold_on_required") if sold_on.blank?

      if service_note.present? && service_note.user_id != user.id
        raise ArgumentError, I18n.t("care_products.errors.wrong_service_note_user")
      end
    end

    def validate_stock!
      raise ArgumentError, I18n.t("care_products.errors.not_enough_stock") if quantity > care_product.stock_quantity.to_i
    end
  end
end

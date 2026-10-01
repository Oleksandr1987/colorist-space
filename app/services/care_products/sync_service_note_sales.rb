# frozen_string_literal: true

module CareProducts
  class SyncServiceNoteSales
    attr_reader :service_note

    def initialize(service_note:)
      @service_note = service_note
    end

    def call
      CareProduct.transaction do
        sync_sales
      end
    end

    private

    def sync_sales
      products.each do |product_id, item|
        sale = sales_by_product_id[product_id]

        if sale
          update_sale(sale, item)
        else
          create_sale(item)
        end
      end

      remove_missing_sales
    end

    def update_sale(sale, item)
      product = sale.care_product

      product.with_lock do
        new_quantity = item["qty"].to_i
        quantity_diff = new_quantity - sale.quantity

        validate_product_status!(product, quantity_diff)
        validate_stock!(product, quantity_diff)

        unless quantity_diff.zero?
          new_stock = product.stock_quantity.to_i - quantity_diff

          create_adjustment_movement(product, quantity: -quantity_diff, unit_cost: sale.unit_cost, stock_after: new_stock)

          product.update!(stock_quantity: new_stock)
        end

        sale.update!(
          quantity: new_quantity,
          unit_price: item["price"].to_d,
          sold_on: service_note.appointment_date
        )
      end
    end

    def create_sale(item)
      product = service_note.user.care_products.find_by(id: item["care_product_id"])

      return unless product

      CareProducts::Sell.new(
        user: service_note.user,
        care_product: product,
        quantity: item["qty"],
        unit_price: item["price"],
        sold_on: service_note.appointment_date,
        service_note: service_note
      ).call
    end

    def remove_missing_sales
      service_note.care_product_sales.where.not(care_product_id: products.keys).find_each do |sale|
        restore_sale(sale)
      end
    end

    def restore_sale(sale)
      product = sale.care_product

      product.with_lock do
        validate_product_status!(product, -sale.quantity)

        new_stock = product.stock_quantity.to_i + sale.quantity

        create_adjustment_movement(product, quantity: sale.quantity, unit_cost: sale.unit_cost, stock_after: new_stock)

        product.update!(stock_quantity: new_stock)

        sale.destroy!
      end
    end

    def create_adjustment_movement(product, quantity:, unit_cost:, stock_after:)
      service_note.user.care_product_stock_movements.create!(
        care_product: product,
        service_note: service_note,
        movement_type: "adjustment",
        adjustment_reason: "service_note_sync",
        quantity: quantity,
        unit_cost: unit_cost,
        stock_after: stock_after,
        occurred_on: service_note.appointment_date
      )
    end

    def validate_stock!(product, quantity_diff)
      return unless quantity_diff.positive?
      return if quantity_diff <= product.stock_quantity.to_i

      raise ArgumentError, I18n.t("care_products.errors.not_enough_stock")
    end

    def products
      @products ||= Array(service_note.care_products).index_by do |item|
        item["care_product_id"].to_s
      end
    end

    def sales_by_product_id
      @sales_by_product_id ||=
        service_note.care_product_sales.index_by do |sale|
          sale.care_product_id.to_s
        end
    end

    def validate_product_status!(product, quantity_diff)
      return if quantity_diff.zero?

      raise ArgumentError, I18n.t("care_products.errors.deleted_product") if product.deleted?
      raise ArgumentError, I18n.t("care_products.errors.archived_product") if product.archived?
    end
  end
end

# frozen_string_literal: true

module CareProducts
  class CancelServiceNoteSales
    attr_reader :service_note

    def initialize(service_note:)
      @service_note = service_note
    end

    def call
      CareProduct.transaction do
        service_note.care_product_sales.find_each do |sale|
          cancel_sale(sale)
        end
      end
    end

    private

    def cancel_sale(sale)
      product = sale.care_product

      product.with_lock do
        service_note.user.care_product_stock_movements.create!(
          care_product: product,
          service_note: service_note,
          movement_type: "adjustment",
          adjustment_reason: "service_note_cancel",
          quantity: sale.quantity,
          unit_cost: sale.unit_cost,
          occurred_on: service_note.appointment_date
        )

        product.update!(stock_quantity: product.stock_quantity.to_i + sale.quantity)

        sale.destroy!
      end
    end
  end
end

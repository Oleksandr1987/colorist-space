# frozen_string_literal: true

module Appointments
  class Destroy
    attr_reader :appointment

    def initialize(appointment:)
      @appointment = appointment
    end

    def call
      Appointment.transaction do
        cancel_care_product_sales!
        appointment.destroy!
      end
    end

    private

    def cancel_care_product_sales!
      appointment.care_product_sales.order(:care_product_id, :id).each do |sale|
        cancel_sale!(sale)
      end
    end

    def cancel_sale!(sale)
      product = sale.care_product

      product.with_lock do
        quantity = sale.quantity
        new_stock = product.stock_quantity.to_i + quantity

        appointment.user.care_product_stock_movements.create!(
          care_product: product,
          movement_type: "adjustment",
          adjustment_reason: "appointment_cancel",
          quantity: quantity,
          unit_cost: sale.unit_cost,
          stock_after: new_stock,
          occurred_on: Date.current
        )

        product.update!(stock_quantity: new_stock)
      end
    end
  end
end

module CareProductsHelper
  def care_product_movement_title(movement)
    t(
      "care_products.history.types.#{movement.history_type}",
      default: movement.history_type.to_s.humanize
    )
  end

  def care_product_movement_quantity(movement)
    quantity = movement.quantity.to_i

    quantity.positive? ? "+#{quantity}" : quantity.to_s
  end

  def care_product_money(value)
    number_to_currency(
      value.to_d,
      unit: "₴",
      format: "%n %u",
      precision: 2,
      strip_insignificant_zeros: true
    )
  end
end

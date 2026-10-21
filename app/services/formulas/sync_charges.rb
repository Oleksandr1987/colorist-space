module Formulas
  class SyncCharges
    attr_reader :service_note

    def initialize(service_note:)
      @service_note = service_note
    end

    def call
      FormulaCharge.transaction do
        service_note.formula_charges.destroy_all

        create_color_charges
        create_oxidant_charges
      end
    end

    private

    def create_color_charges
      service_note.formula_steps.each do |step|
        step.formula_ingredients.each do |ingredient|
          next unless ingredient.amount.to_d.positive?

          product = ingredient.formula_product

          service_note.formula_charges.create!(
            user: service_note.user,
            appointment: service_note.appointment,
            formula_product: product,
            kind: "color",
            brand: product&.brand,
            product_name: ingredient.shade,
            amount: ingredient.amount,
            unit: product&.unit,
            unit_price: ingredient.price,
            total: ingredient.total_price
          )
        end
      end
    end

    def create_oxidant_charges
      service_note.formula_steps.each do |step|
        step.oxidant_data.each do |oxidant|
          amount = oxidant["amount"].to_d

          next unless amount.positive?

          product =
            service_note.user.formula_products.find_by(
              id: oxidant["formula_product_id"]
            )

          unit_price = oxidant["price"].to_d

          service_note.formula_charges.create!(
            user: service_note.user,
            appointment: service_note.appointment,
            formula_product: product,
            kind: "oxidant",
            brand: product&.brand,
            product_name: product&.name || "Oxidant",
            amount: amount,
            unit: product&.unit,
            unit_price: unit_price,
            total: amount * unit_price
          )
        end
      end
    end
  end
end

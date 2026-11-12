# app/services/analytics/income_filter_options.rb

module Analytics
  class IncomeFilterOptions < BaseSummary
    def call
      {
        services: service_options,
        formula: {
          colors: formula_options("color"),
          additives: formula_options("additive"),
          oxidants: formula_options("oxidant")
        },
        care_products: care_options
      }
    end

    private

    def service_options
      service_ids = period_service_relations
        .where(appointment_id: period_appointment_ids)
        .where.not(service_id: nil)
        .distinct
        .pluck(:service_id)

      user.services
        .appointment_services
        .where(id: service_ids)
        .order(:category, :subtype, :name)
        .map do |service|
          {
            id: service.id,
            category: service.category,
            label: service.subtype
          }
        end
    end

    def formula_options(kind)
      scope = case kind
      when "color"
        period_formula_charges.colors
      when "additive"
        period_formula_charges.additives
      when "oxidant"
        period_formula_charges.oxidants
      end

      return [] unless scope

      product_ids = scope
        .where.not(formula_product_id: nil)
        .distinct
        .pluck(:formula_product_id)

      user.formula_products
        .where(id: product_ids)
        .order(:brand, :name)
        .map do |product|
          {
            id: product.id,
            brand: product.brand,
            label: [ product.brand, product.name ].compact_blank.join(" ")
          }
        end
    end

    def care_options
      product_ids = period_care_product_sales
        .distinct
        .pluck(:care_product_id)

      user.care_products
        .where(id: product_ids)
        .order(:brand, :category, :name)
        .map do |product|
          {
            id: product.id,
            brand: product.brand,
            category: product.category,
            label: product.display_name
          }
        end
    end
  end
end

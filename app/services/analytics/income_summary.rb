module Analytics
  class IncomeSummary < BaseSummary
    attr_reader :service_categories, :service_ids, :formula_product_ids, :care_product_ids

    def initialize(user:, from:, to:, service_categories: [], service_ids: [], formula_product_ids: [], care_product_ids: [])
      super(user: user, from: from, to: to)

      @service_categories = normalize_values(service_categories)
      @service_ids = normalize_ids(service_ids)
      @formula_product_ids = normalize_ids(formula_product_ids)
      @care_product_ids = normalize_ids(care_product_ids)
    end

    def service_relations
      @service_relations ||=
        period_service_relations.for_categories(service_categories).for_services(service_ids).where(appointment_id: appointment_ids)
    end

    def grouped_service_income
      @grouped_service_income ||= service_relations.group(:service_category).sum(:price)
    end

    def service_income
      @service_income ||= service_relations.sum(:price)
    end

    def formula_income
      @formula_income ||= formula_charges.sum(:total)
    end

    def care_products_income
      @care_products_income ||= care_product_sales.sum("unit_price * quantity")
    end

    def total_income
      @total_income ||= service_income + formula_income + care_products_income
    end

    def formula_color_options
      @formula_color_options ||=
        period_formula_charges
          .colors
          .where.not(formula_product_id: nil)
          .select(:formula_product_id, :brand, :product_name)
          .distinct
          .map do |charge|
            {
              id: charge.formula_product_id,
              brand: charge.brand,
              label: [ charge.brand, charge.product_name ].compact_blank.join(" ")
            }
          end
          .sort_by { |option| option[:label].downcase }
    end

    def oxidant_options
      @oxidant_options ||=
        period_formula_charges
          .oxidants
          .where.not(formula_product_id: nil)
          .select(:formula_product_id, :brand, :product_name)
          .distinct
          .map do |charge|
            {
              id: charge.formula_product_id,
              brand: charge.brand,
              label: [ charge.brand, charge.product_name ].compact_blank.join(" ")
            }
          end
          .sort_by { |option| option[:label].downcase }
    end

    def care_product_options
      @care_product_options ||=
        care_product_sales
          .includes(:care_product)
          .map do |sale|
            product = sale.care_product

            {
              id: product.id,
              brand: product.brand,
              category: product.category,
              label: product.display_name
            }
          end
          .uniq { |option| option[:id] }
          .sort_by { |option| option[:label].downcase }
    end

    def expanded_relations(category)
      return AppointmentServicesRelation.none unless valid_category?(category)

      service_relations
        .where(service_category: category)
        .includes(:service, :appointment)
        .ordered_for_income
    end

    def monthly_income(category)
      expanded_relations(category).group_by do |relation|
        I18n.l(relation.appointment.appointment_date, format: "%B %Y")
      end
    end

    def formula_color_income
      @formula_color_income ||=
        formula_charges
          .colors
          .where.not(formula_product_id: nil)
          .group_by(&:formula_product_id)
          .map do |product_id, charges|
            first = charges.first

            {
              id: product_id,
              label: [ first.brand, first.product_name ].compact_blank.join(" "),
              amount: charges.sum(&:total)
            }
          end
          .sort_by { |item| item[:label].downcase }
    end

    def oxidant_income
      @oxidant_income ||=
        formula_charges
          .oxidants
          .where.not(formula_product_id: nil)
          .group_by(&:formula_product_id)
          .map do |product_id, charges|
            first = charges.first

            {
              id: product_id,
              label: [ first.brand, first.product_name ].compact_blank.join(" "),
              amount: charges.sum(&:total)
            }
          end
          .sort_by { |item| item[:label].downcase }
    end

    def care_product_income
      @care_product_income ||=
        care_product_sales
          .includes(:care_product)
          .group_by(&:care_product_id)
          .map do |product_id, sales|
            {
              id: product_id,
              label: sales.first.care_product.display_name,
              amount: sales.sum(&:revenue)
            }
          end
          .sort_by { |item| item[:label].downcase }
    end

    def formula_color_brands
      @formula_color_brands ||= formula_color_options.filter_map { |option| option[:brand].presence }.uniq.sort
    end

    def oxidant_brands
      @oxidant_brands ||= oxidant_options.filter_map { |option| option[:brand].presence }.uniq.sort
    end

    def care_product_brands
      @care_product_brands ||= care_product_options.filter_map { |option| option[:brand].presence }.uniq.sort
    end

    def care_product_categories
      @care_product_categories ||= care_product_options.filter_map { |option| option[:category].presence }.uniq.sort
    end

    def available_formula_colors
      @available_formula_colors ||=
        user.formula_products
          .colors
          .order(:brand, :name)
          .map do |product|
            {
              id: product.id,
              brand: product.brand,
              label: formula_product_label(product)
            }
          end
    end

    def available_formula_color_brands
      @available_formula_color_brands ||= available_formula_colors.filter_map { |option| option[:brand].presence }.uniq.sort
    end

    def available_oxidants
      @available_oxidants ||=
        user.formula_products
          .oxidants
          .order(:brand, :name)
          .map do |product|
            {
              id: product.id,
              brand: product.brand,
              label: formula_product_label(product)
            }
          end
    end

    def available_oxidant_brands
      @available_oxidant_brands ||= available_oxidants.filter_map { |option| option[:brand].presence }.uniq.sort
    end

    def available_care_products
      @available_care_products ||=
        user.care_products
          .order(:brand, :name)
          .map do |product|
            {
              id: product.id,
              brand: product.brand,
              category: product.category,
              label: product.display_name
            }
          end
    end

    def available_care_product_brands
      @available_care_product_brands ||= available_care_products.filter_map { |option| option[:brand].presence }.uniq.sort
    end

    def available_care_product_categories
      @available_care_product_categories ||= available_care_products.filter_map { |option| option[:category].presence }.uniq.sort
    end

    private

    def appointment_ids
      @appointment_ids ||=
        begin
          ids = period_appointment_ids

          ids &= service_filtered_appointment_ids if service_filters?
          ids &= formula_filtered_appointment_ids if formula_product_ids.present?
          ids &= care_product_filtered_appointment_ids if care_product_ids.present?

          ids
        end
    end

    def service_filtered_appointment_ids
      period_service_relations
        .for_categories(service_categories)
        .for_services(service_ids)
        .distinct
        .pluck(:appointment_id)
    end

    def formula_filtered_appointment_ids
      period_formula_charges
        .where(formula_product_id: formula_product_ids)
        .distinct
        .pluck(:appointment_id)
    end

    def care_product_filtered_appointment_ids
      period_care_product_sales
        .where(care_product_id: care_product_ids)
        .where.not(appointment_id: nil)
        .distinct
        .pluck(:appointment_id)
    end

    def care_product_sales
      @care_product_sales ||=
        begin
          scope = period_care_product_sales

          if service_filters? || formula_product_ids.present?
            scope = scope.where(appointment_id: appointment_ids)
          end

          if care_product_ids.present?
            scope = scope.where(care_product_id: care_product_ids)
          end

          scope
        end
    end

    def service_filters?
      service_categories.present? || service_ids.present?
    end

    def appointment_filters?
      service_filters? || formula_product_ids.present?
    end

    def valid_category?(category)
      category.present? && grouped_service_income.key?(category)
    end

    def normalize_ids(values)
      Array(values).compact_blank.filter_map { |id| Integer(id, exception: false) }.uniq
    end

    def normalize_values(values)
      Array(values).compact_blank.uniq
    end

    def formula_product_label(product)
      [ product.brand, product.name ].compact_blank.join(" ")
    end

    def formula_color_label(ingredient)
      [ ingredient.brand, ingredient.shade ].compact_blank.join(" ")
    end

    def oxidant_label(product, id)
      return "Oxidant ##{id}" unless product

      [ product.brand, product.name ].compact_blank.join(" ")
    end

    def oxidant_product_ids
      @oxidant_product_ids ||=
        period_service_notes
          .flat_map(&:formula_steps)
          .flat_map(&:oxidant_data)
          .filter_map { |oxidant| Integer(oxidant["formula_product_id"], exception: false) }
          .uniq
    end

    def oxidant_products
      @oxidant_products ||= user.formula_products.where(id: oxidant_product_ids, category: "oxidant").index_by(&:id)
    end

    def formula_charges
      @formula_charges ||=
        begin
          scope = period_formula_charges.where(appointment_id: appointment_ids)

          if formula_product_ids.present?
            scope = scope.where(formula_product_id: formula_product_ids)
          end

          scope
        end
    end
  end
end

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
      @grouped_service_income ||=
        service_relations.joins(:service).group("services.category").sum("appointment_services_relations.price")
    end

    def service_income
      @service_income ||= service_relations.sum(:price)
    end

    def service_notes
      @service_notes ||= period_service_notes.select { |note| appointment_ids.include?(note.appointment_id) }
    end

    def formula_income
      @formula_income ||= service_notes.sum(&:formula_ingredients_total_price)
    end

    def care_products_income
      @care_products_income ||= service_notes.sum(&:care_products_income)
    end

    def total_income
      @total_income ||= service_income + formula_income + care_products_income
    end

    def formula_color_options
      @formula_color_options ||=
        period_service_notes
          .flat_map(&:formula_steps)
          .flat_map(&:formula_ingredients)
          .filter_map do |ingredient|
            next if ingredient.formula_product_id.blank?

            {
              id: ingredient.formula_product_id,
              brand: ingredient.brand,
              label: formula_color_label(ingredient)
            }
          end
          .uniq { |option| option[:id] }
          .sort_by { |option| option[:label].downcase }
    end

    def oxidant_options
      @oxidant_options ||=
        oxidant_product_ids
          .map do |id|
            {
              id: id,
              brand: oxidant_products[id]&.brand,
              label: oxidant_label(oxidant_products[id], id)
            }
          end
          .sort_by { |option| option[:label].downcase }
    end

    def care_product_options
      @care_product_options ||=
        begin
          items = period_service_notes.flat_map { |note| Array(note.care_products) }

          ids = items.filter_map { |item| Integer(item["care_product_id"], exception: false) }.uniq

          products = user.care_products.where(id: ids).index_by(&:id)

          items
            .filter_map do |item|
              id = Integer(item["care_product_id"], exception: false)
              next if id.blank?

              product = products[id]

              {
                id: id,
                brand: product&.brand,
                category: product&.category,
                label: item["name"].presence || product&.display_name || "##{id}"
              }
            end
            .uniq { |option| option[:id] }
            .sort_by { |option| option[:label].downcase }
        end
    end

    def expanded_relations(category)
      return AppointmentServicesRelation.none unless valid_category?(category)

      service_relations
        .joins(:service)
        .where(services: { category: category })
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
        service_notes
        .flat_map(&:formula_steps)
        .flat_map(&:formula_ingredients)
        .group_by(&:formula_product_id)
        .filter_map do |product_id, ingredients|
          next if product_id.blank?

          {
            id: product_id,
            label: formula_color_label(ingredients.first),
            amount: ingredients.sum(&:total_price)
          }
        end
        .sort_by { |item| item[:label].downcase }
    end

    def oxidant_income
      @oxidant_income ||=
        begin
          products = oxidant_products

          service_notes
            .flat_map(&:formula_steps)
            .flat_map(&:oxidant_data)
            .group_by { |oxidant| oxidant["formula_product_id"].to_i }
            .filter_map do |product_id, oxidants|
              next if product_id.zero?

              {
                id: product_id,
                label: oxidant_label(products[product_id], product_id),
                amount: oxidants.sum do |oxidant|
                  oxidant["amount"].to_f * oxidant["price"].to_f
                end
              }
            end
            .sort_by { |item| item[:label].downcase }
        end
    end

    def care_product_income
      @care_product_income ||=
        service_notes
        .flat_map { |note| Array(note.care_products) }
        .group_by { |item| item["care_product_id"].to_i }
        .filter_map do |product_id, items|
          next if product_id.zero?

          {
            id: product_id,
            label: items.first["name"].presence || "##{product_id}",
            amount: items.sum do |item|
              item["price"].to_f * item["qty"].to_i
            end
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
      period_service_notes.select { |note| note_matches_formula_filter?(note) }.map(&:appointment_id)
    end

    def care_product_filtered_appointment_ids
      period_service_notes.select { |note| note_matches_care_product_filter?(note) }.map(&:appointment_id)
    end

    def note_matches_formula_filter?(note)
      note.formula_steps.any? do |step|
        ingredient_match =
          step.formula_ingredients.any? do |ingredient|
            formula_product_ids.include?(ingredient.formula_product_id)
          end

        oxidant_match =
          step.oxidant_data.any? do |oxidant|
            formula_product_ids.include?(oxidant["formula_product_id"].to_i)
          end

        ingredient_match || oxidant_match
      end
    end

    def note_matches_care_product_filter?(note)
      Array(note.care_products).any? do |item|
        care_product_ids.include?(item["care_product_id"].to_i)
      end
    end

    def service_filters?
      service_categories.present? || service_ids.present?
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
  end
end

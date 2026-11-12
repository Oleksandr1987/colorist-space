
# app/services/analytics/income_report.rb

module Analytics
  class IncomeReport
    GROUPS = %w[services formula care_products].freeze
    FORMULA_KINDS = %w[color additive oxidant].freeze

    attr_reader :user, :from, :to, :params

    # FILTER OPTIONS
    attr_reader(
      :filter_services,
      :filter_categories,
      :filter_colors,
      :filter_additives,
      :filter_oxidants,
      :filter_color_brands,
      :filter_additive_brands,
      :filter_oxidant_brands,
      :filter_care_products,
      :filter_care_brands,
      :filter_care_categories
    )

    # SELECTED FILTERS
    attr_reader(
      :category_filters,
      :service_filters,
      :formula_product_filters,
      :care_product_filters,
      :income_groups_applied,
      :income_groups,
      :formula_kinds
    )

    # INCOME DATA
    attr_reader(
      :grouped_income,
      :formula_income,
      :care_products_income,
      :formula_color_income,
      :oxidant_income,
      :additive_income,
      :care_product_income,
      :total_income,
      :display_total_income,
      :display_formula_income,
      :expanded_income_category,
      :monthly_income
    )

    def initialize(user:, from:, to:, params:)
      @user = user
      @from = from
      @to = to
      @params = params
    end

    def call
      load_filter_options
      load_selected_filters
      load_summary
      calculate_display_totals

      self
    end

    private

    def load_filter_options
      options = Analytics::IncomeFilterOptions.new(user: user, from: from, to: to).call

      services = options[:services] || []

      service_ids = services.map { |service| service[:id] }

      @filter_services = user.services.appointment_services.where(id: service_ids).ordered_for_filter

      @filter_categories = services.map { |service| service[:category] }.compact.uniq

      @filter_colors = options.dig(:formula, :colors) || []
      @filter_additives = options.dig(:formula, :additives) || []
      @filter_oxidants = options.dig(:formula, :oxidants) || []

      @filter_color_brands = brands_for(@filter_colors)
      @filter_additive_brands = brands_for(@filter_additives)
      @filter_oxidant_brands = brands_for(@filter_oxidants)

      @filter_care_products = options[:care_products] || []

      @filter_care_brands = brands_for(@filter_care_products)

      @filter_care_categories = @filter_care_products
        .map { |product| product[:category] }
        .compact_blank
        .uniq
        .sort
    end

    def load_selected_filters
      @category_filters = Array(params[:income_categories])
        .select { |category| filter_categories.include?(category) }

      @service_filters = normalize_ids(params[:service_ids])

      @formula_product_filters =
        normalize_ids(params[:formula_product_ids])

      @care_product_filters =
        normalize_ids(params[:care_product_ids])

      @income_groups_applied =
        params[:income_groups_applied] == "1"

      @income_groups =
        if income_groups_applied
          Array(params[:income_groups]) & GROUPS
        else
          []
        end

      @formula_kinds =
        if income_groups_applied && income_groups.include?("formula")
          Array(params[:formula_kinds]) & FORMULA_KINDS
        else
          []
        end
    end

    def load_summary
      summary = Analytics::IncomeSummary.new(
        user: user,
        from: from,
        to: to,
        service_categories: category_filters,
        service_ids: service_filters,
        formula_product_ids: formula_product_filters,
        care_product_ids: care_product_filters
      )

      @grouped_income = summary.grouped_service_income
      @formula_income = summary.formula_income
      @care_products_income = summary.care_products_income

      @formula_color_income = summary.formula_color_income
      @oxidant_income = summary.oxidant_income
      @additive_income = summary.additive_income
      @care_product_income = summary.care_product_income

      @total_income = summary.total_income

      @expanded_income_category =
        params[:expanded] if grouped_income.key?(params[:expanded])

      @monthly_income =
        if expanded_income_category.present?
          summary.monthly_income(expanded_income_category)
        else
          {}
        end
    end

    def calculate_display_totals
      @display_formula_income =
        if income_groups_applied && formula_kinds.any?
          formula_kinds.sum { |kind| formula_kind_total(kind) }
        else
          formula_income.to_f
        end

      @display_total_income =
        if income_groups_applied
          selected_groups_total
        else
          total_income.to_f
        end
    end

    def selected_groups_total
      total = 0.0

      if income_groups.include?("services")
        total += grouped_income.values.compact.sum
      end

      if income_groups.include?("formula")
        total += display_formula_income
      end

      if income_groups.include?("care_products")
        total += care_products_income.to_f
      end

      total
    end

    def formula_kind_total(kind)
      items =
        case kind
        when "color"
          formula_color_income
        when "additive"
          additive_income
        when "oxidant"
          oxidant_income
        else
          []
        end

      items.sum { |item| item[:amount].to_f }
    end

    def brands_for(options)
      options
        .map { |option| option[:brand] }
        .compact_blank
        .uniq
        .sort
    end

    def normalize_ids(values)
      Array(values)
        .filter_map { |id| Integer(id, exception: false) }
        .uniq
    end
  end
end

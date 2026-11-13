module Analytics
  class IncomePresentation
    FORMULA_SECTIONS = {
      "color" => {
        title_key: "formula_products.tabs.colors",
        items_method: :formula_color_income
      },
      "additive" => {
        title_key: "formula_products.tabs.additives",
        items_method: :additive_income
      },
      "oxidant" => {
        title_key: "analytics.income.oxidants",
        items_method: :oxidant_income
      }
    }.freeze

    attr_reader :report, :params, :from, :to, :all_time

    def initialize(report:, params:, from:, to:, all_time:)
      @report = report
      @params = params
      @from = from
      @to = to
      @all_time = all_time
    end

    def show_services?
      show_group?("services")
    end

    def show_formula?
      show_group?("formula") &&
        report.display_formula_income.to_f.positive?
    end

    def show_care_products?
      show_group?("care_products") &&
        report.care_products_income.to_f.positive?
    end

    def show_content?
      has_income? || filters_applied?
    end

    def has_income?
      (show_services? && report.grouped_income.present?) ||
        show_formula? ||
        show_care_products?
    end

    def filters_applied?
      params[:all_time] == "1" ||
        params[:from].present? ||
        params[:to].present? ||
        params[:income_groups_applied] == "1" ||
        %i[
          income_categories
          service_ids
          formula_kinds
          formula_product_ids
          care_product_ids
        ].any? { |key| params[key].present? }
    end

    def formula_sections
      FORMULA_SECTIONS.filter_map do |kind, config|
        next unless show_formula_kind?(kind)

        items = report.public_send(config[:items_method])
        next if items.blank?

        {
          kind: kind,
          title_key: config[:title_key],
          items: items,
          total: items.sum { |item| item[:amount].to_f }
        }
      end
    end

    def category_params(category)
      result = {
        tab: "income",
        income_categories: report.category_filters,
        service_ids: report.service_filters,
        formula_product_ids: report.formula_product_filters,
        care_product_ids: report.care_product_filters,
        income_groups: report.income_groups,
        formula_kinds: report.formula_kinds
      }

      if report.income_groups_applied
        result[:income_groups_applied] = "1"
      end

      if all_time
        result[:all_time] = "1"
      elsif period_filter_applied?
        result[:from] = from.strftime("%d.%m.%Y")
        result[:to] = to.strftime("%d.%m.%Y")
      end

      unless report.expanded_income_category == category
        result[:expanded] = category
      end

      result
    end

    private

    def show_group?(group)
      !report.income_groups_applied ||
        report.income_groups.include?(group)
    end

    def show_formula_kind?(kind)
      !report.income_groups_applied ||
        report.formula_kinds.empty? ||
        report.formula_kinds.include?(kind)
    end

    def period_filter_applied?
      all_time ||
        params[:from].present? ||
        params[:to].present?
    end
  end
end

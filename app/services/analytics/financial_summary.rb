module Analytics
  class FinancialSummary < BaseSummary
    def service_income
      @service_income ||= period_service_relations.sum(:price)
    end

    def formula_income
      @formula_income ||= period_service_notes.sum(&:formula_ingredients_total_price)
    end

    def care_products_income
      @care_products_income ||= period_service_notes.sum(&:care_products_income)
    end

    def total_income
      @total_income ||= service_income + formula_income + care_products_income
    end

    def manual_expenses
      @manual_expenses ||= Expense.for_user_between(user, from, to).sum(:amount)
    end

    def care_products_cost
      @care_products_cost ||= period_service_notes.sum(&:care_products_cost)
    end

    def total_expenses
      @total_expenses ||= manual_expenses + care_products_cost
    end

    def balance
      @balance ||= total_income - total_expenses
    end
  end
end

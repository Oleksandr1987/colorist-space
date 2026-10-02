module Analytics
  class BaseSummary
    attr_reader :user, :from, :to

    def initialize(user:, from:, to:)
      @user = user
      @from = from
      @to = to
    end

    private

    def period_appointment_ids
      @period_appointment_ids ||=
        begin
          scope = user.appointments
          scope = scope.where(appointment_date: from..to) if period?

          scope.pluck(:id)
        end
    end

    def period_service_relations
      @period_service_relations ||=
        if period?
          AppointmentServicesRelation.for_user_between(user, from, to)
        else
          AppointmentServicesRelation.for_user(user.id)
        end
    end

    def period_service_notes
      @period_service_notes ||=
        ServiceNote
          .where(user: user, appointment_id: period_appointment_ids)
          .includes(formula_steps: :formula_ingredients)
          .to_a
    end

    def period_care_product_sales
      @period_care_product_sales ||=
        begin
          scope = user.care_product_sales
          scope = scope.where(sold_on: from..to) if period?

          scope
        end
    end

    def period?
      from.present? && to.present?
    end
  end
end

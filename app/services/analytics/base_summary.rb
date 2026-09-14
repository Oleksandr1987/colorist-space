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
        user
          .appointments
          .where(appointment_date: from..to)
          .pluck(:id)
    end

    def period_service_relations
      @period_service_relations ||= AppointmentServicesRelation.for_user_between(user, from, to)
    end

    def period_service_notes
      @period_service_notes ||=
        ServiceNote
          .where(user: user, appointment_id: period_appointment_ids)
          .includes(formula_steps: :formula_ingredients)
          .to_a
    end
  end
end

class Service < ApplicationRecord
  belongs_to :user, optional: true

  has_many :appointment_services_relations, inverse_of: :service, dependent: :destroy
  has_many :appointments, through: :appointment_services_relations

  validates :name, presence: true
  validates :category, presence: true, if: -> { service_type == "service" }
  validates :subtype, presence: true
  validates :price, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :service_type, inclusion: { in: %w[service preparation care_product] }

  scope :income_for_user_between, ->(user, from, to) {
    joins(:appointments)
      .where(appointments: { user_id: user.id, appointment_date: from..to })
  }

  scope :apply_income_filters, ->(filters) {
    scope = self

    scope = scope.where(service_type: filters[:service_type]) if filters[:service_type].present?

    if filters[:service_type] == "service"
      scope = scope.where(category: filters[:category]) if filters[:category].present?
      scope = scope.where(subtype: filters[:subtype]) if filters[:subtype].present?
    end

    scope
  }

  def self.grouped_income(scope, service_type)
    if service_type.present?
      if service_type == "service"
        scope.group(:subtype).sum(:price)
      else
        scope.group(:name).sum(:price)
      end
    else
      scope.group(:service_type).sum(:price)
    end
  end

  def self.monthly_income(scope)
    scope
      .select("appointments.appointment_date AS date, services.*")
      .order("appointments.appointment_date DESC")
      .group_by(&:service_type)
      .transform_values do |group|
        group.group_by { |s| Date.parse(s.date.to_s).strftime("%B %Y") }
      end
  end
end

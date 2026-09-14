class Service < ApplicationRecord
  CATEGORIES = %w[
    haircut
    coloring
    styling
    treatment
  ].freeze

  belongs_to :user, optional: true

  has_many :appointment_services_relations, inverse_of: :service, dependent: :destroy
  has_many :appointments, through: :appointment_services_relations

  validates :name, presence: true
  validates :category, presence: true, if: -> { service_type == "service" }
  validates :subtype, presence: true
  validates :price, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :service_type, inclusion: { in: %w[service] }

  before_validation :sync_name

  scope :appointment_services, -> { where(service_type: "service") }

  scope :with_category, -> { where.not(category: [ nil, "" ]) }

  scope :ordered_for_filter, -> { order(:category, :subtype) }

  scope :categories, -> { appointment_services.with_category.distinct.pluck(:category).sort }

  scope :for_filter, ->(categories = nil) {
    scope = appointment_services
    categories = Array(categories).reject(&:blank?)
    scope = scope.where(category: categories) if categories.any?

    scope.ordered_for_filter
  }

  scope :ordered_by_subtype, -> { order(:subtype) }

  scope :for_user, ->(user) { where(user: user) }

  scope :for_category, ->(category) { where(category: category) }

  scope :for_user_and_category, ->(user, category) {
    for_user(user)
      .appointment_services
      .for_category(category)
      .ordered_by_subtype
  }

  class << self
    def categories_for_user(user)
    for_user(user)
      .appointment_services
      .with_category
      .distinct
      .order(:category)
      .pluck(:category)
    end

    def normalize_category(category)
      return if category.blank?

      value = category.to_s.strip.downcase

      return value if CATEGORIES.include?(value)

      CATEGORIES.find do |key|
        I18n.t("services.categories.#{key}").casecmp?(category)
      end || category
    end
  end

  private

  def sync_name
    self.name = subtype if subtype.present?
  end
end

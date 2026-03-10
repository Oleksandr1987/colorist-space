class Expense < ApplicationRecord
  belongs_to :user

  validates :category, presence: true
  validates :amount, numericality: { only_integer: true, greater_than: 0 }
  validates :spent_on, presence: true
  validate :spent_on_cannot_be_in_the_future

  CATEGORIES = %w[
    rent
    materials
    advertising
    transport
    care_products
    tools
    utilities
    other
  ].freeze

  scope :ordered_by_date, -> { order(spent_on: :desc) }

  scope :for_user_between, ->(user, from, to) {
    where(user: user, spent_on: from..to)
  }

  scope :apply_category_filter, ->(category) {
    category.present? ? where(category: category) : all
  }

  def self.monthly_expenses(scope)
    scope
      .ordered_by_date
      .group_by { |expense| I18n.l(expense.spent_on, format: "%B %Y") }
  end

  def self.grouped_expenses(scope)
    scope.group(:category).sum(:amount)
  end

  def self.total_expenses(scope)
    scope.sum(:amount)
  end

  def category_name
    I18n.t("analytics.expenses.categories.#{category}")
  end

  private

  def spent_on_cannot_be_in_the_future
    return unless spent_on.present? && spent_on > Date.today

    errors.add(:spent_on, "Please select a date in the past or today")
  end
end

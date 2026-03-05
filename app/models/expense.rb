class Expense < ApplicationRecord
  belongs_to :user

  validates :category, presence: true
  validates :amount, numericality: { only_integer: true, greater_than: 0 }
  validates :spent_on, presence: true
  validate :spent_on_cannot_be_in_the_future

  CATEGORIES = [
    "Оренда",
    "Матеріали",
    "Реклама",
    "Транспорт",
    "Засоби догляду",
    "Інструменти",
    "Комунальні платежі",
    "Інше"
  ].freeze

  scope :for_user_between, ->(user, from, to) {
    where(user: user, spent_on: from..to)
  }

  scope :apply_category_filter, ->(category) {
    category.present? ? where(category: category) : self
  }

  def self.grouped_expenses(scope)
    scope.group(:category).sum(:amount)
  end

  def self.total_expenses(scope)
    scope.sum(:amount)
  end

  def self.monthly_expenses(scope)
    scope
      .order(spent_on: :desc)
      .group_by { |e| e.spent_on.strftime("%B %Y") }
  end

  private

  def spent_on_cannot_be_in_the_future
    if spent_on.present? && spent_on > Date.today
      errors.add(:spent_on, "Please select a date in the past or today")
    end
  end
end

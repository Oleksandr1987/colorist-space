class Expense < ApplicationRecord
  belongs_to :user

  validates :category, presence: true
  validates :amount, numericality: { only_integer: true, greater_than: 0 }
  validates :spent_on, presence: true
  validate :spent_on_cannot_be_in_the_future

  CATEGORIES = ['Оренда', 'Матеріали', 'Реклама', 'Транспорт', 'Засоби догляду', 'Інструменти', 'Комунальні платежі', 'Інше'].freeze

  def spent_on_cannot_be_in_the_future
    if spent_on.present? && spent_on > Date.today
      errors.add(:spent_on, "Please select a date in the past or today")
    end
  end
end

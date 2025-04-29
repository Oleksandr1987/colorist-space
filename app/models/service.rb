class Service < ApplicationRecord
  belongs_to :user, optional: true

  validates :name, presence: true
  validates :category, presence: true
  validates :subtype, presence: true
  validates :price, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :service_type, inclusion: { in: %w[service preparation care_product] }
end

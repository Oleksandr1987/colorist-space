class CareProduct < ApplicationRecord
  belongs_to :user

  CATEGORIES = [
    "Shampoo",
    "Mask",
    "Conditioner",
    "Oil",
    "Spray",
    "Cream",
    "Treatment"
  ].freeze

  validates :name, presence: true

  validates :sale_price,
    numericality: {
      greater_than_or_equal_to: 0
    },
    allow_nil: true

  validates :purchase_price,
    numericality: {
      greater_than_or_equal_to: 0
    },
    allow_nil: true

  validates :stock_quantity,
    numericality: {
      greater_than_or_equal_to: 0
    },
    allow_nil: true

  def incomplete?
    purchase_price.blank? ||
      stock_quantity.blank?
  end

  def display_name
    [ brand, name ].compact.join(" ")
  end
end

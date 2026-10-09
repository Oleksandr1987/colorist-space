# frozen_string_literal: true

class CareProductSale < ApplicationRecord
  belongs_to :user
  belongs_to :care_product
  belongs_to :appointment, optional: true
  belongs_to :service_note, optional: true
  belongs_to :stock_movement, class_name: "CareProductStockMovement", optional: true

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }
  validates :unit_cost, numericality: { greater_than_or_equal_to: 0 }
  validates :sold_on, presence: true

  def revenue
    unit_price * quantity
  end

  def cost
    unit_cost * quantity
  end

  def profit
    revenue - cost
  end
end

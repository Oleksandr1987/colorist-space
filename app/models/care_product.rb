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

  after_create_commit :broadcast_create
  after_update_commit :broadcast_update
  after_destroy_commit :broadcast_remove

  def incomplete?
    purchase_price.blank? ||
      stock_quantity.blank?
  end

  def display_name
    [ brand, name ].compact.join(" ")
  end

  private

  def broadcast_create
    broadcast_append_to(
      "care_products",
      target: "care_products",
      partial: "care_products/care_product",
      locals: {
        care_product: self
      }
    )
  end

  def broadcast_update
    broadcast_replace_to(
      "care_products",
      target: "care_product_#{id}",
      partial: "care_products/care_product",
      locals: {
        care_product: self
      }
    )
  end

  def broadcast_remove
    broadcast_remove_to(
      "care_products",
      target: "care_product_#{id}"
    )
  end
end

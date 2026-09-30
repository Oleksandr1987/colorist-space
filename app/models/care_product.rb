class CareProduct < ApplicationRecord
  CATEGORIES = %w[
    shampoo
    mask
    conditioner
    oil
    spray
    cream
    treatment
  ].freeze

  belongs_to :user

  has_many :stock_movements, class_name: "CareProductStockMovement", dependent: :destroy
  has_many :sales, class_name: "CareProductSale", dependent: :restrict_with_error

  validate :unique_product_identity
  validates :name, presence: true
  validates :sale_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :purchase_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :stock_quantity, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  before_validation :normalize_identity_fields

  after_create_commit :broadcast_create
  after_update_commit :broadcast_update
  after_destroy_commit :broadcast_remove

  def incomplete?
    purchase_price.blank? || stock_quantity.blank?
  end

  def display_name
    [ brand, name ].compact.join(" ")
  end

  def stock_value
    purchase_price.to_d * stock_quantity.to_i
  end

  def self.total_stock_value
    sum("purchase_price * stock_quantity")
  end

  private

  def normalize_identity_fields
    self.brand = normalize_display_value(brand)
    self.name = normalize_display_value(name)
    self.category = normalize_display_value(category)

    self.normalized_brand = normalize_identity_value(brand)
    self.normalized_name = normalize_identity_value(name)
    self.normalized_category = normalize_identity_value(category)
  end

  def normalize_display_value(value)
    value.to_s.squish.presence
  end

  def normalize_identity_value(value)
    value.to_s.unicode_normalize(:nfkc).squish.downcase
  end

  def unique_product_identity
    return if user.blank? || normalized_name.blank?

    duplicate =
      user.care_products
          .where.not(id: id)
          .exists?(normalized_brand: normalized_brand, normalized_name: normalized_name, normalized_category: normalized_category)

    return unless duplicate

    errors.add(:name, I18n.t("care_products.errors.already_exists"))
  end

  def broadcast_create
    broadcast_append_to(
      "care_products",
      target: "care_products",
      partial: "care_products/care_product",
      locals: { care_product: self }
    )
  end

  def broadcast_update
    broadcast_replace_to(
      "care_products",
      target: "care_product_#{id}",
      partial: "care_products/care_product",
      locals: { care_product: self }
    )
  end

  def broadcast_remove
    broadcast_remove_to("care_products", target: "care_product_#{id}")
  end
end

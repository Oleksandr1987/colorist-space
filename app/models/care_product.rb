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

  scope :active, -> { where(archived_at: nil, deleted_at: nil) }
  scope :archived, -> { where.not(archived_at: nil).where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }

  def archived?
    archived_at.present?
  end

  def archive!
  return false if deleted?

    if stock_quantity.to_i.positive?
      errors.add(:base, I18n.t("care_products.errors.cannot_archive_with_stock"))
      raise ActiveRecord::RecordInvalid, self
    end

    update!(archived_at: Time.current)
  end

  def restore!
    return false if deleted?

    update!(archived_at: nil)
  end

  def incomplete?
    purchase_price.blank? || stock_quantity.blank?
  end

  def deleted?
    deleted_at.present?
  end

  def soft_delete!
    if stock_quantity.to_i.positive?
      errors.add(:base, I18n.t("care_products.errors.cannot_delete_with_stock"))
      raise ActiveRecord::RecordInvalid, self
    end

    update!(deleted_at: Time.current, archived_at: nil)
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

  def archived_duplicate
    return if user.blank? || normalized_name.blank?

    user.care_products
        .archived
        .find_by(normalized_brand: normalized_brand, normalized_name: normalized_name, normalized_category: normalized_category)
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
    return if user.blank? || normalized_name.blank? || deleted?

    duplicate =
      user.care_products
          .where(deleted_at: nil)
          .where.not(id: id)
          .find_by(
            normalized_brand: normalized_brand,
            normalized_name: normalized_name,
            normalized_category: normalized_category
          )

    return unless duplicate

    error_key = duplicate.archived? ? :archived_duplicate : :already_exists

    errors.add(:name, I18n.t("care_products.errors.#{error_key}"))
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

class CareProductStockMovement < ApplicationRecord
  MOVEMENT_TYPES = %w[
    opening_balance
    purchase
    sale
    adjustment
  ].freeze

  ADJUSTMENT_REASONS = %w[
    inventory
    damaged
    expired
    personal_use
    missing
    data_correction
    service_note_sync
    service_note_cancel
    other
  ].freeze

  belongs_to :user
  belongs_to :care_product
  belongs_to :service_note, optional: true
  belongs_to :expense, optional: true

  has_one :care_product_sale, foreign_key: :stock_movement_id, dependent: :nullify

  validates :movement_type, presence: true, inclusion: { in: MOVEMENT_TYPES }
  validates :quantity, numericality: { only_integer: true, other_than: 0 }
  validates :unit_cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :occurred_on, presence: true
  validates :adjustment_reason, presence: true, inclusion: { in: ADJUSTMENT_REASONS }, if: :adjustment?

  validate :care_product_belongs_to_user
  validate :opening_balance_has_positive_quantity
  validate :purchase_has_positive_quantity
  validate :sale_has_negative_quantity

  scope :ordered, -> { order(occurred_on: :desc, created_at: :desc) }
  scope :purchases, -> { where(movement_type: "purchase") }
  scope :sales, -> { where(movement_type: "sale") }
  scope :adjustments, -> { where(movement_type: "adjustment") }

  private

  def adjustment?
    movement_type == "adjustment"
  end

  def care_product_belongs_to_user
    return if user.blank? || care_product.blank?
    return if care_product.user_id == user_id

    errors.add(:care_product, "must belong to the same user")
  end

  def opening_balance_has_positive_quantity
    return unless movement_type == "opening_balance"
    return if quantity.blank? || quantity.positive?

    errors.add(:quantity, "must be positive for opening balance")
  end

  def purchase_has_positive_quantity
    return unless movement_type == "purchase"
    return if quantity.blank? || quantity.positive?

    errors.add(:quantity, "must be positive for purchase")
  end

  def sale_has_negative_quantity
    return unless movement_type == "sale"
    return if quantity.blank? || quantity.negative?

    errors.add(:quantity, "must be negative for sale")
  end
end

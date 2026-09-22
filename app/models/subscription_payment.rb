# frozen_string_literal: true

class SubscriptionPayment < ApplicationRecord
  STATUSES = %w[pending approved declined refunded voided].freeze
  CALLBACK_FIELDS = %w[
    merchantAccount orderReference amount currency transactionStatus
    reasonCode authCode processingDate createdDate
  ].freeze

  belongs_to :subscription
  validates :source, inclusion: { in: %w[purchase regular_status] }

  validates :merchant_account, :order_reference, presence: true
  validates :order_reference, uniqueness: { scope: :merchant_account }
  validates :plan, inclusion: { in: Subscription::PAID_PLANS }
  validates :amount_minor, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, inclusion: { in: [ "UAH" ] }
  validates :status, inclusion: { in: STATUSES }
  validate :period_is_ordered

  def amount
    BigDecimal(amount_minor.to_s) / 100
  end

  def processed?
    processed_at.present?
  end

  # Call only after signature verification and amount/currency/order checks.
  def assign_callback_metadata(payload)
    self.callback_metadata = payload.stringify_keys.slice(*CALLBACK_FIELDS)
  end

  private

  def period_is_ordered
    return unless period_start && period_end
    return if period_end > period_start

    errors.add(:period_end, :greater_than, count: period_start)
  end
end

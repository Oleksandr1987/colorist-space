# frozen_string_literal: true

class Subscription < ApplicationRecord
  PLANS = %w[none trial monthly yearly].freeze
  PAID_PLANS = %w[monthly yearly].freeze
  STATUSES = %w[pending trialing active past_due cancelled expired].freeze

  belongs_to :user
  has_many :subscription_payments, dependent: :restrict_with_error

  validates :user_id, uniqueness: true
  validates :source, inclusion: { in: %w[wayforpay] }
  validates :plan, inclusion: { in: PLANS }
  validates :status, inclusion: { in: STATUSES }
  validates :next_plan, inclusion: { in: PAID_PLANS }, allow_nil: true
  validates :auto_renew, inclusion: { in: [ true, false ] }
  validates :merchant_account, :wayforpay_order_reference, presence: true, if: :auto_renew?
  validates :wayforpay_order_reference, uniqueness: { scope: :merchant_account }, allow_nil: true
  validate :period_is_ordered
  validate :next_plan_is_complete
  validate :renewal_matches_plan

  # End is exclusive. Cancellation stops renewal but preserves purchased access.
  # Access is time-based: status alone must never grant an extra paid period.
  def paid_access?(at: Time.current)
    plan.in?(PAID_PLANS) &&
      current_period_end.present? && current_period_end > at &&
      (current_period_start.nil? || current_period_start <= at)
  end

  def on_trial?(at: Time.current)
    plan == "trial" && trial_ends_at.present? && trial_ends_at > at
  end

  def write_access?(at: Time.current)
    paid_access?(at: at) || on_trial?(at: at)
  end

  def expires_soon?(at: Time.current)
    paid_access?(at: at) && current_period_end <= at + 3.days
  end

  def trial_days_left(at: Time.current)
    return 0 unless trial_ends_at

    [ ((trial_ends_at - at) / 1.day).ceil, 0 ].max
  end

  def display_status(at: Time.current)
    return "trialing" if on_trial?(at: at)
    return "cancelled" if paid_access?(at: at) && cancelled_at.present?
    return "active" if paid_access?(at: at)
    return "expired" if current_period_end.present? || trial_ends_at.present?

    status
  end

  private

  def period_is_ordered
    return unless current_period_start && current_period_end
    return if current_period_end > current_period_start

    errors.add(:current_period_end, :greater_than, count: current_period_start)
  end

  def next_plan_is_complete
    return if next_plan.present? == next_plan_starts_at.present?

    errors.add(:next_plan_starts_at, :blank) if next_plan.present?
    errors.add(:next_plan, :blank) if next_plan_starts_at.present?
  end

  def renewal_matches_plan
    return unless auto_renew?
    return if source == "wayforpay" && plan.in?(PAID_PLANS) && cancelled_at.nil?

    errors.add(:auto_renew, :invalid)
  end
end

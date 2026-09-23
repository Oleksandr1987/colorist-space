module SubscriptionsHelper
  def subscription_end_label(subscription)
    ends_at = subscription&.current_period_end || subscription&.trial_ends_at
    ends_at ? (ends_at - 1.second).strftime("%d.%m.%Y") : "—"
  end

  def subscription_price(plan)
    number_to_currency(BigDecimal(Wayforpay::Config.amount_minor(plan).to_s) / 100,
      unit: "₴", format: "%n %u")
  rescue Wayforpay::Error
    "—"
  end
end

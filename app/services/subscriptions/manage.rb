module Subscriptions
  class Manage
    def self.call(subscription, action, plan: nil, client: Wayforpay::Client.new)
      raise Wayforpay::Error, "No subscription" unless subscription
      # Save intent BEFORE network I/O so retries can repair a remote success/local failure.
      subscription.with_lock do
        raise Wayforpay::Error, "No provider agreement" if subscription.wayforpay_order_reference.blank?
        raise Wayforpay::Error, "Merchant mismatch" unless subscription.merchant_account == Wayforpay::Config.merchant
        intent = subscription.management_intent
        if intent.present? && (intent["action"] != action || intent["plan"] != plan)
          raise Wayforpay::Error, "Finish the pending subscription operation first"
        end
        if intent.blank?
          if action == "change"
            raise Wayforpay::Error, "Invalid plan" unless Subscription::PAID_PLANS.include?(plan)
            raise Wayforpay::Error, "No active period to change" unless subscription.paid_access?
            raise Wayforpay::Error, "Already on this plan" if subscription.plan == plan
          end
          subscription.update!(management_intent: { action: action, plan: plan,
            amount_minor: plan ? Wayforpay::Config.amount_minor(plan) : nil,
            starts_on: subscription.current_period_end&.to_date&.iso8601 })
        end
      end
      subscription.with_lock do
        intent = subscription.management_intent
        raise Wayforpay::Error, "Missing operation" if intent.blank?
        ref = subscription.wayforpay_order_reference
        status = client.regular("STATUS", ref)
        raise Wayforpay::Error, "Provider reference mismatch" unless status["orderReference"] == ref
        if action == "cancel"
          client.regular("REMOVE", ref) unless status["status"] == "Removed"
          subscription.update!(auto_renew: false, cancelled_at: Time.current,
            provider_status: "Removed", status: "cancelled", management_intent: nil,
            next_plan: nil, next_plan_starts_at: nil, next_amount_minor: nil)
        else
          raise Wayforpay::Error, "Agreement is not active" unless status["status"] == "Active"
          starts_on = Date.iso8601(intent.fetch("starts_on"))
          raise Wayforpay::Error, "Scheduled change date has passed; reconcile first" unless starts_on > Date.current
          amount = BigDecimal(intent.fetch("amount_minor").to_s) / 100
          client.regular("CHANGE", ref, regularMode: plan, amount: amount.to_s("F"), currency: "UAH",
            dateBegin: starts_on.strftime("%d.%m.%Y"), dateEnd: (starts_on + 10.years).strftime("%d.%m.%Y"))
          subscription.update!(next_plan: plan, next_plan_starts_at: starts_on.in_time_zone.beginning_of_day,
            next_amount_minor: intent["amount_minor"], auto_renew: true, management_intent: nil)
        end
      end
    end
  end
end

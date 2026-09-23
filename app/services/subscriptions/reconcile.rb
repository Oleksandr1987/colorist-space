require "digest"
module Subscriptions
  class Reconcile
    def self.call(subscription, client: Wayforpay::Client.new)
      raise Wayforpay::Error, "No subscription" unless subscription
      subscription.with_lock do
        raise Wayforpay::Error, "Retry pending management operation first" if subscription.management_intent.present?
        # Recover an initial payment even when its webhook was missed.
        payment = subscription.subscription_payments.find_by(id: subscription.checkout_payment_id)

        if payment && !payment.processed?
          result = client.check(payment.order_reference)
          ApplyPurchase.call(payment, result) unless result["transactionStatus"] == "NotFound"
          subscription.reload
        end

        reference = subscription.wayforpay_order_reference

        return if reference.blank?

        raise Wayforpay::Error, "Merchant mismatch; retain old credentials until agreements are closed" unless
          subscription.merchant_account == Wayforpay::Config.merchant

        body = client.regular("STATUS", reference)

        raise Wayforpay::Error, "STATUS reference mismatch" unless body["orderReference"] == reference

        apply_status(subscription, body)
      end
    end

    def self.apply_status(subscription, body)
      provider_status = body.fetch("status")

      raise Wayforpay::Error, "Unknown regular status" unless
        %w[Active Suspended Created Removed Confirmed Completed].include?(provider_status)

      raise Wayforpay::Error, "Invalid regular currency" unless body["currency"] == "UAH"

      expected_plan = subscription.next_plan.presence || subscription.plan
      expected_amount = subscription.next_amount_minor || subscription.renewal_amount_minor

      if provider_status == "Active" && (body["mode"] != expected_plan || !expected_amount ||
          BigDecimal(body.fetch("amount").to_s) * 100 != expected_amount)
        raise Wayforpay::Error, "Regular schedule mismatch; cancel or inspect agreement"
      end

      subscription.provider_status = provider_status
      subscription.auto_renew = provider_status == "Active" && subscription.cancelled_at.nil?
      subscription.last_synced_at = Time.current
      paid_at = timestamp(body["lastPayedDate"])
      next_at = timestamp(body["nextPaymentDate"])

      # STATUS only exposes the latest payment; this is a reconciliation receipt,
      # not a fabricated provider transaction ID or complete transaction history.
      if body["lastPayedStatus"] == "Approved" && paid_at && next_at &&
          (!subscription.last_provider_paid_at || paid_at > subscription.last_provider_paid_at)

        expected_plan = subscription.next_plan.presence || subscription.plan
        expected_amount = subscription.next_amount_minor || subscription.renewal_amount_minor

        unless body["mode"] == expected_plan && expected_amount &&
            BigDecimal(body.fetch("amount").to_s) * 100 == expected_amount
          raise Wayforpay::Error, "Regular schedule mismatch; inspect before extending access"
        end

        max_end = expected_plan == "yearly" ? paid_at + 1.year + 2.days : paid_at + 1.month + 2.days
        raise Wayforpay::Error, "Invalid provider period" unless next_at > paid_at && next_at <= max_end

        # A late status read of the first payment does not extend beyond its paid end.
        if (subscription.current_period_end.nil? || next_at > subscription.current_period_end) &&
            (subscription.current_period_end.nil? || paid_at >= subscription.current_period_end - 1.day)

          local_reference = "status/#{Digest::SHA256.hexdigest(subscription.wayforpay_order_reference)[0, 24]}/#{paid_at.to_i}"
          receipt = subscription.subscription_payments.find_or_initialize_by(
            merchant_account: subscription.merchant_account, order_reference: local_reference)

          unless receipt.processed?
            receipt.assign_attributes(
              source: "regular_status",
              plan: expected_plan,
              amount_minor: expected_amount,
              currency: "UAH",
              status: "approved",
              provider_status: "Approved",
              paid_at: paid_at,
              processed_at: Time.current,
              period_start: paid_at,
              period_end: next_at,
              callback_metadata: { "regularReference" => subscription.wayforpay_order_reference,
                "lastPayedDate" => paid_at.to_i, "nextPaymentDate" => next_at.to_i }
            )

            receipt.save!
            subscription.plan = expected_plan
            subscription.renewal_amount_minor = expected_amount
            subscription.current_period_start = paid_at
            subscription.current_period_end = next_at
            subscription.next_plan = nil
            subscription.next_plan_starts_at = nil
            subscription.next_amount_minor = nil
            subscription.status = "active"
          end
        end

        subscription.last_provider_paid_at = paid_at
      end

      subscription.save!

    rescue KeyError, ArgumentError, TypeError
      raise Wayforpay::Error, "Malformed STATUS response"
    end

    def self.timestamp(value)
      return nil if value.blank?

      number = Integer(value)

      raise Wayforpay::Error, "Invalid provider timestamp" unless number.positive?
      Time.zone.at(number)
    end
  end
end

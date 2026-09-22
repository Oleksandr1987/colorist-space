module Subscriptions
  class ApplyPurchase
    def self.call(payment, payload)
      subscription = payment.subscription
      subscription.with_lock do
        payment.reload
        # A root-reference callback for a later charge can have a different amount.
        # Its access is reconciled via STATUS; it must not reapply this purchase.
        if payment.status == "voided" && payload["transactionStatus"] == "Approved"
          raise Wayforpay::Error, "Late approval of an abandoned checkout requires review"
        end

        return if payment.processed? || payment.status.in?(%w[refunded voided])

        unless BigDecimal(payload.fetch("amount").to_s) == payment.amount &&
               payload["currency"] == payment.currency &&
               payload["merchantAccount"] == payment.merchant_account &&
               payload["orderReference"] == payment.order_reference
          raise Wayforpay::Error, "Payment does not match the stored order"
        end

        payment.assign_callback_metadata(payload)
        payment.provider_status = payload["transactionStatus"]
        payment.reason_code = payload["reasonCode"].to_s

        case payload["transactionStatus"]
        when "Approved"
          raise Wayforpay::Error, "Unexpected approval code" unless payload["reasonCode"].to_s == "1100"
          if subscription.checkout_payment_id != payment.id
            raise Wayforpay::Error, "Historical checkout needs manual review"
          end

          subscription.update!(source: "wayforpay", plan: payment.plan, status: "active",
            current_period_start: payment.period_start, current_period_end: payment.period_end,
            merchant_account: payment.merchant_account,
            wayforpay_order_reference: payment.order_reference,
            renewal_amount_minor: payment.amount_minor, cancelled_at: nil,
            # Approval proves a purchase, not that the regular agreement is Active.
            auto_renew: false, provider_status: "Unverified")
          payment.status = "approved"
          payment.paid_at = Time.current
          payment.processed_at = Time.current

        when "Declined", "Expired"
          payment.status = "declined"

        when "Refunded", "Voided"
          payment.status = payload["transactionStatus"].downcase
        end
        payment.save!
      end

    rescue ArgumentError, KeyError
      raise Wayforpay::Error, "Invalid payment data"
    end
  end
end

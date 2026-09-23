module Subscriptions
  class ApplyPurchase
    def self.call(payment, payload)
      subscription = payment.subscription
      subscription.with_lock do
        payment.reload

        unless payload["merchantAccount"] == payment.merchant_account && payload["orderReference"] == payment.order_reference
          raise Wayforpay::Error, "Payment does not match the stored order"
        end

        status = payload["transactionStatus"]
        # Reversals must be recorded even after access was applied. Keep
        # processed_at and the purchased period; revocation is a separate policy.
        if status.in?(%w[Refunded Voided])
          validate_amount!(payment, payload)
          payment.assign_callback_metadata(payload)
          payment.update!(status: status.downcase, provider_status: status,
            reason_code: payload["reasonCode"].to_s)
          return
        end

        if payment.status == "voided" && status == "Approved"
          raise Wayforpay::Error, "Late approval of an abandoned checkout requires review"
        end

        # A recurring callback may reuse the root reference with another amount.
        # Only the first purchase is applied here; STATUS reconciles renewals.
        return if payment.processed? || payment.status.in?(%w[refunded voided])

        validate_amount!(payment, payload)
        payment.assign_callback_metadata(payload)
        payment.provider_status = status
        payment.reason_code = payload["reasonCode"].to_s

        case status
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
            auto_renew: false, provider_status: "Unverified")
          payment.status = "approved"
          payment.paid_at = Time.current
          payment.processed_at = Time.current
        when "Declined", "Expired"
          payment.status = "declined"
        end
        payment.save!
      end
    rescue ArgumentError, KeyError
      raise Wayforpay::Error, "Invalid payment data"
    end

    def self.validate_amount!(payment, payload)
      unless BigDecimal(payload.fetch("amount").to_s) == payment.amount && payload["currency"] == payment.currency
        raise Wayforpay::Error, "Payment does not match the stored order"
      end
    end
    private_class_method :validate_amount!
  end
end

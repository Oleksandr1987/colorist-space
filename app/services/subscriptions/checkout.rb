require_relative "../../../lib/wayforpay/signature"
module Subscriptions
  class Checkout
    def self.call(user, plan)
      Wayforpay::Config.validate!
      raise Wayforpay::Error, "Unknown plan" unless Subscription::PAID_PLANS.include?(plan)
      raise Wayforpay::Error, "Superadmin does not need billing" if user.superadmin?
      subscription = user.subscription || user.create_subscription!(plan: "none")
      subscription.with_lock do
        if !subscription.paid_access? && subscription.provider_status == "Removed"
          subscription.update!(checkout_payment_id: nil, wayforpay_order_reference: nil,
            merchant_account: nil, last_provider_paid_at: nil, provider_status: nil,
            cancelled_at: nil, auto_renew: false)
        end
        if subscription.paid_access? || subscription.wayforpay_order_reference.present?
          raise Wayforpay::Error, "Use subscription management before opening another checkout"
        end
        payment = subscription.subscription_payments.find_by(id: subscription.checkout_payment_id)
        if payment
          # Reuse within its lifetime. After expiry, consult the provider before
          # replacing an abandoned checkout; a timeout never permits a new order.
          return payment if payment.checkout_expires_at > Time.current
          remote = Wayforpay::Client.new.check(payment.order_reference)
          if remote["transactionStatus"] == "Approved"
            ApplyPurchase.call(payment, remote)
            return payment
          end
          unless %w[NotFound Expired Declined Voided].include?(remote["transactionStatus"])
            raise Wayforpay::Error, "Previous payment is still in progress"
          end
          payment.update!(status: "voided")
          subscription.update!(checkout_payment_id: nil)
        end
        now = Time.current
        # Checkout is limited to 15 minutes. Dates are frozen into this order.
        end_date = plan == "yearly" ? Date.current.next_year : Date.current.next_month
        payment = subscription.subscription_payments.create!(
          merchant_account: Wayforpay::Config.merchant,
          order_reference: "cs_#{SecureRandom.uuid}", plan: plan,
          amount_minor: Wayforpay::Config.amount_minor(plan),
          checkout_expires_at: now + 15.minutes,
          period_start: now, period_end: end_date.in_time_zone.beginning_of_day
        )
        payment.update!(checkout_data: form(payment, user))
        subscription.update!(checkout_payment_id: payment.id)
        payment
      end
    end

    def self.form(payment, user)
      amount = payment.amount.to_s("F")
      product = I18n.t("subscription.products.#{payment.plan}")
      domain = Wayforpay::Config.required(:merchant_domain)
      fields = [ payment.merchant_account, domain, payment.order_reference,
        payment.created_at.to_i, amount, "UAH", product, 1, amount ]
      {
        merchantAccount: payment.merchant_account, merchantDomainName: domain,
        merchantAuthType: "SimpleSignature", merchantTransactionSecureType: "AUTO",
        orderReference: payment.order_reference, orderDate: payment.created_at.to_i,
        amount: amount, currency: "UAH", productName: [ product ],
        productCount: [ 1 ], productPrice: [ amount ], clientEmail: user.email,
        clientFirstName: user.name, language: I18n.locale == :uk ? "UA" : "EN",
        paymentSystems: "card;googlePay;applePay", orderLifetime: 900,
        regularOn: 1, regularBehavior: "preset", regularMode: payment.plan,
        regularAmount: amount, dateNext: payment.period_end.strftime("%d.%m.%Y"),
        dateEnd: (Date.current + 10.years).strftime("%d.%m.%Y"),
        serviceUrl: "#{Wayforpay::Config.base_url}/subscription/payment_callback",
        returnUrl: "#{Wayforpay::Config.base_url}/subscription/payment_return",
        merchantSignature: Wayforpay::Signature.generate(fields, Wayforpay::Config.secret)
      }
    end
  end
end

require "digest"
require_relative "../../../lib/wayforpay/signature"
module Wayforpay
  class Webhook
    SIGNED_FIELDS = %w[merchantAccount orderReference amount currency authCode cardPan transactionStatus reasonCode].freeze
    class InvalidSignature < Error; end

    def self.call(payload)
      Config.validate!
      unless payload.is_a?(Hash) && SIGNED_FIELDS.all? { |k| payload.key?(k) && !payload[k].is_a?(Array) && !payload[k].is_a?(Hash) }
        raise InvalidSignature, "Malformed callback"
      end

      expected = Signature.generate(SIGNED_FIELDS.map { |k| payload[k] }, Config.secret)
      unless payload["merchantAccount"] == Config.merchant &&
          ActiveSupport::SecurityUtils.secure_compare(expected, payload["merchantSignature"].to_s)
        raise InvalidSignature, "Invalid callback signature"
      end

      metadata = payload.slice(*SubscriptionPayment::CALLBACK_FIELDS)
      fingerprint = Digest::SHA256.hexdigest(JSON.generate(SIGNED_FIELDS.map { |k| payload[k].to_s }))
      event = WayforpayEvent.create_or_find_by!(fingerprint: fingerprint) do |row|
        row.merchant_account = payload["merchantAccount"]
        row.order_reference = payload["orderReference"]
        row.metadata = metadata
      end

      if event.state == "received"
        payment = SubscriptionPayment.find_by(merchant_account: event.merchant_account,
          order_reference: event.order_reference, source: "purchase")
        if payment
          # A later callback may reuse the root reference for a renewal.
          # Never apply it a second time; STATUS is authoritative for renewals.
          Subscriptions::ApplyPurchase.call(payment, payload)
          event.update!(state: "processed")
        else
          event.update!(state: "unmatched")
        end
      end

      now = Time.current.to_i
      { orderReference: payload["orderReference"], status: "accept", time: now,
        signature: Signature.generate([ payload["orderReference"], "accept", now ], Config.secret) }
    end
  end
end

require "uri"
module Wayforpay
  class Config
    class << self
      def get(key, default = nil)
        env_key = "WAYFORPAY_#{key.to_s.upcase}"

        return ENV[env_key] if ENV.key?(env_key)
        value = Rails.application.credentials.dig(:wayforpay, key)
        value.nil? ? default : value
      end

      def required(key)
        get(key).presence || raise(Error, "WayForPay configuration missing: #{key}")
      end

      def merchant
        required(:merchant_account).to_s
      end

      def secret
        required(:secret_key).to_s
      end

      def password
        required(:merchant_password).to_s
      end

      def demo?
        get(:demo, "true").to_s == "true"
      end

      def validate!
        if Rails.env.production? && (demo? || merchant == "test_merch_n1")
          raise Error, "Test WayForPay configuration is disabled in production"
        end

        required(:merchant_domain)
        secret
        base_url
      end

      def base_url
        value = required(:public_base_url).to_s.delete_suffix("/")
        uri = URI.parse(value)

        raise Error, "Use an HTTPS public_base_url without a path" unless
          uri.scheme == "https" && uri.host.present? && uri.userinfo.nil? &&
          uri.query.nil? && uri.fragment.nil? && uri.path.empty?
        value

      rescue URI::InvalidURIError
        raise Error, "Invalid public_base_url"
      end

      def amount_minor(plan)
        raise Error, "Unknown plan" unless %w[monthly yearly].include?(plan)
        value = Integer(required(:"#{plan}_amount_minor"))
        raise Error, "Invalid price" unless value.positive?
        value

      rescue ArgumentError, TypeError
        raise Error, "Invalid price"
      end
    end
  end
end

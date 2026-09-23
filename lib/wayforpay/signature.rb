require "openssl"
module Wayforpay
  class Signature
    def self.generate(fields, secret_key)
      OpenSSL::HMAC.hexdigest("MD5", secret_key, fields.map(&:to_s).join(";"))
    end
  end
end

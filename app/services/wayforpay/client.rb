require "net/http"
require "json"
require_relative "../../../lib/wayforpay/signature"

module Wayforpay
  class Client
    def regular(type, reference, **attributes)
      request("https://api.wayforpay.com/regularApi", {
        requestType: type, merchantAccount: Config.merchant,
        merchantPassword: Config.password, orderReference: reference
      }.merge(attributes)).tap do |body|
        raise Error, "Regular API rejected request (#{body['reasonCode']})" unless body["reasonCode"].to_s == "4100"
      end
    end

    def check(reference)
      body = request("https://api.wayforpay.com/api", {
        transactionType: "CHECK_STATUS", merchantAccount: Config.merchant,
        orderReference: reference, apiVersion: 1,
        merchantSignature: Signature.generate([ Config.merchant, reference ], Config.secret)
      })
      # Request-level Order Not Found can omit the normal transaction signature.
      # This result is accepted only from the fixed HTTPS API, never from a webhook.
      return { "transactionStatus" => "NotFound", "orderReference" => reference } if body["reasonCode"].to_s == "1127"

      raise Error, "Unexpected CHECK_STATUS response" unless
        body["orderReference"] == reference && body["merchantAccount"] == Config.merchant

      fields = %w[merchantAccount orderReference amount currency authCode cardPan transactionStatus reasonCode]
      expected = Signature.generate(fields.map { |k| body[k] }, Config.secret)

      raise Error, "Invalid CHECK_STATUS signature" unless
        ActiveSupport::SecurityUtils.secure_compare(expected, body["merchantSignature"].to_s)
      body
    end

    private

    def request(url, payload)
      Config.validate!
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 10
      http.write_timeout = 10
      req = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "application/json"
      req.body = JSON.generate(payload)
      response = http.request(req)

      raise Error, "WayForPay HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      body = JSON.parse(response.body)
      raise Error, "Invalid API response" unless body.is_a?(Hash)

      body

    rescue JSON::ParserError, IOError, SystemCallError, SocketError,
           Timeout::Error, OpenSSL::SSL::SSLError, Net::HTTPBadResponse => e
      # No response bodies, tokens, passwords or request URLs in logs.
      raise Error, "WayForPay transport error: #{e.class.name}"
    end
  end
end

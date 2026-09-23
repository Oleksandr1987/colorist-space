# No ApplicationController browser/auth filters on provider callbacks.
class WayforpayCallbacksController < ActionController::Base
  skip_forgery_protection

  def create
    raw = request.get_header(WayforpayBodyLimit::BODY_KEY)
    # Fail closed if the required middleware was not installed.
    unless raw
      Rails.logger.error("WayForPay body-limit middleware is missing")
      return head :internal_server_error
    end
    payload = if raw.lstrip.start_with?("{")
      JSON.parse(raw)
    else
      request.request_parameters.to_h
    end
    render json: Wayforpay::Webhook.call(payload)
  rescue Wayforpay::Webhook::InvalidSignature
    head :forbidden
  rescue JSON::ParserError, ActionDispatch::Http::Parameters::ParseError
    head :bad_request
  rescue Wayforpay::Error => e
    Rails.logger.warn("WayForPay callback: #{e.message}")
    head :unprocessable_content
  end

  def payment_return
    redirect_to settings_subscription_path(locale: I18n.default_locale), status: :see_other
  end
end

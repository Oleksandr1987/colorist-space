# No browser, session, locale, Devise or Pundit filters on server-to-server requests.
class WayforpayCallbacksController < ActionController::Base
  skip_forgery_protection

  def create
    raise JSON::ParserError if request.raw_post.bytesize > 64.kilobytes
    payload = if request.raw_post.lstrip.start_with?("{")
      JSON.parse(request.raw_post)
    else
      request.request_parameters.to_h
    end
    render json: Wayforpay::Webhook.call(payload)
  rescue Wayforpay::Webhook::InvalidSignature
    head :forbidden
  rescue JSON::ParserError
    head :bad_request
  rescue Wayforpay::Error => e
    Rails.logger.warn("WayForPay callback: #{e.message}")
    head :unprocessable_entity
  end

  # Browser return is not proof of payment. No subscription mutation here.
  def payment_return
    redirect_to settings_subscription_path(locale: I18n.default_locale), status: :see_other
  end
end

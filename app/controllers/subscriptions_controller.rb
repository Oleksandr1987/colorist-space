class SubscriptionsController < ApplicationController

  MERCHANT_LOGIN = "473b_ngrok_free_app" # заміни на свій
  SECRET_KEY = "0a3178120edbddaf1e403c6f4c595373cdfd177d" # заміни на свій

  def activate_monthly
    order_reference = "monthly_#{SecureRandom.hex(5)}"
    amount = 1 # змінити на актуальну ціну
    product_name = "Colorist Space – підписка на 1 місяць"

    @plan = "monthly"
    @form_data = build_wayforpay_form(order_reference, amount, product_name)

    render :payment_form
  end

  def activate_yearly
    order_reference = "yearly_#{SecureRandom.hex(5)}"
    amount = 10 # змінити на актуальну ціну
    product_name = "Colorist Space – підписка на 1 рік"

    @plan = "yearly"
    @form_data = build_wayforpay_form(order_reference, amount, product_name)

    render :payment_form
  end

  def cancel
    current_user.update!(
      plan_name: nil,
      subscription_expires_at: nil
    )
    redirect_to settings_subscription_path, notice: "Підписку скасовано"
  end

  def payment_callback
    order_reference = params[:orderReference]
    status = params[:transactionStatus]
    email = params[:clientEmail]

    signature_fields = [
      params[:merchantAccount],
      order_reference,
      params[:amount],
      params[:currency],
      params[:authCode],
      params[:cardPan],
      params[:transactionStatus],
      params[:reasonCode]
    ]

    expected_signature = Wayforpay::Signature.generate(signature_fields, SECRET_KEY)

    unless expected_signature == params[:merchantSignature]
      Rails.logger.warn "⚠️ Невірний підпис у payment_callback!"
      return head :forbidden
    end

    if status == "Approved"
      user = User.find_by(email: email)

      if user
        duration = order_reference.start_with?("yearly") ? 1.year : 1.month

        user.update!(
          plan_name: order_reference.start_with?("yearly") ? "yearly" : "monthly",
          subscription_expires_at: duration.from_now.to_date
        )

        Rails.logger.info "✅ Підписку активовано для #{user.email} до #{user.subscription_expires_at}"
      else
        Rails.logger.error "❌ Не знайдено користувача з email #{email}"
      end
    else
      Rails.logger.warn "Платіж не підтверджено: #{status} для #{order_reference}"
    end

    head :ok
  end

  private

  def build_wayforpay_form(order_reference, amount, product_name)
    merchant_domain = request.host
    order_date = Time.now.to_i

    data_for_signature = [
      MERCHANT_LOGIN,
      order_reference,
      order_date.to_s,
      amount.to_s,
      "UAH",
      product_name,
      "1",
      amount.to_s
    ]

    {
      merchantAccount: MERCHANT_LOGIN,
      merchantDomainName: merchant_domain,
      orderReference: order_reference,
      orderDate: order_date,
      amount: amount,
      currency: "UAH",
      productName: [product_name],
      productPrice: [amount],
      productCount: [1],
      clientFirstName: current_user.name,
      clientEmail: current_user.email,
      merchantSignature: Wayforpay::Signature.generate(data_for_signature, SECRET_KEY)
    }
  end
end

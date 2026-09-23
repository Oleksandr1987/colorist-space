# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [ :create ]
  before_action :configure_account_update_params, only: [ :update ]

  def destroy
    # Preserve active paid access, payment history
    # and provider agreements until the account deletion workflow handles them.
    subscription = resource.subscription
    if subscription&.paid_access? || subscription&.subscription_payments&.exists? ||
        subscription&.wayforpay_order_reference.present?
      redirect_to settings_subscription_path,
        alert: I18n.t("subscription.account_deletion_blocked"), status: :see_other
      return
    end
    resource.transaction do
      resource.subscription&.destroy!
      # Reload clears the cached has_one association before dependent checks.
      resource.reload
      super
    end
  end

  protected

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up,
      keys: [ :name, :email, :phone, :password, :password_confirmation, :tos_agreement ])
  end

  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update,
      keys: [ :name, :email, :phone, :password, :password_confirmation, :current_password ])
  end
end

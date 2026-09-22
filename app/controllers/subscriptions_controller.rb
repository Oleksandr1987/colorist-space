class SubscriptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_account
  rescue_from Wayforpay::Error, with: :billing_error

  def activate_monthly
    checkout("monthly")
  end

  def activate_yearly
    checkout("yearly")
  end

  def cancel
    Subscriptions::Manage.call(current_user.subscription, "cancel")
    redirect_to settings_subscription_path, notice: t("subscription.cancelled"), status: :see_other
  end

  def change_plan
    Subscriptions::Manage.call(current_user.subscription, "change", plan: params[:plan])
    redirect_to settings_subscription_path, notice: t("subscription.plan_changed"), status: :see_other
  end

  def sync
    Subscriptions::Reconcile.call(current_user.subscription)
    redirect_to settings_subscription_path, notice: t("subscription.synced"), status: :see_other
  end

  private

  def authorize_account
    authorize current_user, :subscription?
    head :forbidden if current_user.superadmin?
  end

  def checkout(plan)
    @payment = Subscriptions::Checkout.call(current_user, plan)
    if @payment.processed?
      redirect_to settings_subscription_path, notice: t("subscription.synced"), status: :see_other
      return
    end
    @form_data = @payment.checkout_data
    render :checkout
  end

  def billing_error(error)
    Rails.logger.warn("WayForPay user=#{current_user.id}: #{error.message}")
    redirect_to settings_subscription_path, alert: t("subscription.operation_failed"), status: :see_other
  end
end

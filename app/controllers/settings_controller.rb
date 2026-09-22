class SettingsController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
    authorize @user
  end

  def subscription
    @user = current_user
    authorize @user
    @subscription = @user.subscription
    @payments = @subscription ? @subscription.subscription_payments.order(created_at: :desc).limit(20) : []
  end
end

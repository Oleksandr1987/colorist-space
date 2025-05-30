class SettingsController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
    authorize @user
  end

  def subscription
    @user = current_user
    authorize @user
  end
end

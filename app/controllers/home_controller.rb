class HomeController < ApplicationController
  helper_method :resource, :resource_name, :devise_mapping

  def index
    if user_signed_in?
      redirect_to calendar_appointments_path
    else
      prepare_devise_vars
    end
  end

  private

  def prepare_devise_vars
    @resource = User.new
  end

  def resource
    @resource
  end

  def resource=(val)
    @resource = val
  end

  def resource_name
    :user
  end

  def devise_mapping
    Devise.mappings[:user]
  end
end

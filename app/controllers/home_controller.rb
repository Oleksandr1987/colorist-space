class HomeController < ApplicationController
  before_action :prepare_devise_vars

  helper_method :resource, :resource_name, :devise_mapping

  def index
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

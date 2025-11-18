# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  before_action :normalize_login_phone, only: [:create]
  before_action :configure_sign_in_params, only: [:create]

  def after_sign_in_path_for(resource_or_scope)
    calendar_appointments_path
  end

  def after_sign_out_path_for(resource_or_scope)
    calendar_appointments_path
  end

  # GET /resource/sign_in
  # def new
  #   super
  # end

  # POST /resource/sign_in
  # def create
  #   super
  # end

  # DELETE /resource/sign_out
  # def destroy
  #   super
  # end

  # protected

  # If you have extra params to permit, append them to the sanitizer.
  def normalize_login_phone
    return if params[:user].blank? || params[:user][:login].blank?

    login = params[:user][:login]

    unless login.include?("@")
      normalized = PhoneValidator.normalize(login)
      params[:user][:login] = normalized
    end
  end

  def configure_sign_in_params
    devise_parameter_sanitizer.permit(:sign_in, keys: [:login])
  end
end

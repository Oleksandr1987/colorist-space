# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  before_action :normalize_login_phone, only: [ :create ]
  before_action :configure_sign_in_params, only: [ :create ]

  def after_sign_in_path_for(resource_or_scope)
    calendar_appointments_path
  end

  def after_sign_out_path_for(resource_or_scope)
    root_path
  end

  def create
    self.resource = resource_class.new(sign_in_params)

    normalize_login_phone

    user = User.find_for_database_authentication(
      login: sign_in_params[:login]
    )

    if user&.valid_password?(sign_in_params[:password])
      sign_in(resource_name, user)
      redirect_to after_sign_in_path_for(user)
    else
      resource.errors.add(:base, t("devise.failure.invalid", authentication_keys: "login"))
      clean_up_passwords(resource)
      render :new, status: :unprocessable_content
    end
  end

  private

  def normalize_login_phone
    return if params[:user].blank? || params[:user][:login].blank?

    login = params[:user][:login]

    unless login.include?("@")
      normalized = PhoneValidator.normalize(login)
      params[:user][:login] = normalized
    end
  end

  def configure_sign_in_params
    devise_parameter_sanitizer.permit(:sign_in, keys: [ :login ])
  end
end

# frozen_string_literal: true

class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def facebook
    handle_auth("Facebook")
  end

  def google_oauth2
    handle_auth("Google")
  end

  def instagram
    handle_auth("Instagram")
  end

  private

  def handle_auth(kind)
    @user = User.from_omniauth(auth)
    if @user.present?
      sign_out_all_scopes
      flash[:success] = "Signed in with #{kind} successfully."
      sign_in_and_redirect @user, event: :authentication
    else
      flash[:alert] = "Authentication with #{kind} failed, please try again. #{auth.info.email} is not authorized."
      redirect_to new_user_registration_path
    end
  end

  def auth
    auth ||= request.env["omniauth.auth"]
  end
  # You should configure your model like this:
  # devise :omniauthable, omniauth_providers: [:twitter]

  # You should also create an action method in this controller like this:
  # def twitter
  # end

  # More info at:
  # https://github.com/heartcombo/devise#omniauth

  # GET|POST /resource/auth/twitter
  # def passthru
  #   super
  # end

  # GET|POST /users/auth/twitter/callback
  # def failure
  #   super
  # end

  # protected

  # The path used when OmniAuth fails
  # def after_omniauth_failure_path_for(scope)
  #   super(scope)
  # end
end

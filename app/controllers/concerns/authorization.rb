# frozen_string_literal: true

module Authorization
  extend ActiveSupport::Concern

  included do
    include Pundit::Authorization

    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  end

  class_methods do
    def auto_authorize(resource_name, only: [])
      before_action -> {
        record = instance_variable_get("@#{resource_name}")
        authorize(record || resource_name.to_s.classify.constantize.new)
      }, only: only

      after_action :verify_authorized, only: only
    end
  end

  private

  def user_not_authorized
    flash[:danger] = %(
      You are not authorized to perform this action. You need to have an active subscription.
      <a href="/settings/subscription" class="alert-link">Manage your subscription</a>.
    ).html_safe

  redirect_to(request.referer || root_path)
  end
end

class AnalyticsPolicy < ApplicationPolicy
  def access?
    true if user.has_write_access?
  end
end

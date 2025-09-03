class UserPolicy < ApplicationPolicy
  def show?
    record == user
  end

  def subscription?
    user.present? && user == record
  end
end

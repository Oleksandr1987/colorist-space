class ClientPolicy < ApplicationPolicy
  def update?
    user_owns_client?
  end

  def destroy?
    user_owns_client?
  end

  def delete_photo?
    user_owns_client?
  end

  private

  def user_owns_client?
    record.user_id == user.id
  end
end

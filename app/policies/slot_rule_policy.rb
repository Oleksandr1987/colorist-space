class SlotRulePolicy < ApplicationPolicy
  def create?
    has_write_access?
  end

  def edit?
    update?
  end

  def update?
    owns_record?
  end

  def destroy?
    owns_record?
  end

  private

  def owns_record?
    record.user_id == user.id && has_write_access?
  end
end

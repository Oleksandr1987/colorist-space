class ExpensePolicy < ApplicationPolicy
  def update?
    owns_record?
  end

  def destroy?
    owns_record?
  end

  def edit?
    update?
  end

  def new?
    create?
  end

  def create?
    has_write_access?
  end

  private

  def owns_record?
    record.user_id == user.id && has_write_access?
  end
end

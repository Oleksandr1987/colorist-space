class ServicePolicy < ApplicationPolicy
  def create?
    has_write_access?
  end

  def new?
    create?
  end

  def update?
    owns_record?
  end

  def edit?
    update?
  end

  def destroy?
    owns_record?
  end

  def create_preparation?
    create?
  end

  def create_care_product?
    create?
  end

  private

  def owns_record?
    record.user_id == user.id && has_write_access?
  end
end

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    true
  end

  def show?
    true
  end

  def create?
    has_write_access?
  end

  def new?
    create?
  end

  def update?
    has_write_access?
  end

  def edit?
    update?
  end

  def destroy?
    has_write_access?
  end

  private

  def has_write_access?
    # return true if Rails.env.development? || Rails.env.test?
    return true if user&.superadmin?

    user&.has_active_subscription? || user&.on_trial?
  end
end

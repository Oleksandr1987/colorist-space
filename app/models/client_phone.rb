class ClientPhone < ApplicationRecord
  include PhoneValidator

  belongs_to :client
  belongs_to :user

  before_validation :set_user

  validates :phone,
            presence: true,
            uniqueness: {
              scope: :user_id
            }

  validate :phone_not_used_by_another_client

  private

  def set_user
    self.user_id ||= client&.user_id
  end

  def phone_not_used_by_another_client
    return if phone.blank?

    if Client.where(user_id: user_id)
            .where.not(id: client_id)
            .exists?(phone: phone)
      errors.add(:phone, "already belongs to another client")
    end
  end
end

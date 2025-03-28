module PhoneValidator
  extend ActiveSupport::Concern

  included do
    validates :phone, presence: true, format: { with: /\A(\+380|0)\d{9}\z/, message: 'must be a valid phone number sratrting with +380 or 0 ' }
  end
end
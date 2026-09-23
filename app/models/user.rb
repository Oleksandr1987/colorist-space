class User < ApplicationRecord
  include PhoneValidator
  include SubscriptionAccess

  attr_accessor :login

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: %i[facebook google_oauth2 instagram]

  PASSWORD_FORMAT = /\A
    (?=.*[A-Z])
    (?=.*\d)
    (?=.*[[:^alnum:]])
    .+
  \z/x.freeze

  validates :name, presence: true
  validates :password, format: { with: PASSWORD_FORMAT, message: :weak_password }, if: :password_required?
  validates_acceptance_of :tos_agreement, allow_nil: false, on: :create

  has_many :clients, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :slot_rules, dependent: :destroy
  has_many :services, dependent: :destroy
  has_many :expenses, dependent: :destroy
  has_many :formula_products, dependent: :destroy
  has_many :care_products, dependent: :destroy

  class << self
    def find_for_database_authentication(warden_conditions)
      conditions = warden_conditions.dup
      login = conditions.delete(:login)&.strip
      return nil if login.blank?
      login = PhoneValidator.normalize(login) unless login.include?("@")
      where(conditions).where("LOWER(email) = :value OR phone = :value", value: login.downcase).first
    end

    def from_omniauth(auth)
      if where(email: auth.info.email).exists?
        return_user = where(email: auth.info.email).first
        return_user.provider = auth.provider
        return_user.uid = auth.uid
      else
        return_user = where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
          user.email = auth.info.email
          user.password = "#{Devise.friendly_token[0, 20]}A1!"
          user.name = auth.info.name
          user.phone = auth.info.phone || ""
          user.tos_agreement = true
        end
      end
      return_user
    end
  end

  def superadmin?
    role == "superadmin"
  end
end

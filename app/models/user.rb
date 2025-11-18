class User < ApplicationRecord
  include PhoneValidator

  attr_accessor :login

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: %i[facebook google_oauth2 instagram]

  validates_acceptance_of :tos_agreement, allow_nil: false, on: :create

  has_many :clients, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :slot_rules, dependent: :destroy
  has_many :services, dependent: :destroy
  has_many :expenses, dependent: :destroy

  class << self
    def find_for_database_authentication(warden_conditions)
      conditions = warden_conditions.dup
      login = conditions.delete(:login)&.strip

      if login.present? && !login.include?("@")
        login = PhoneValidator.normalize(login)
      end

      where(conditions).where(
        ["LOWER(email) = :value OR phone = :value", { value: login.downcase }]
      ).first
    end

    def from_omniauth(auth)
      if where(email: auth.info.email).exists?
        return_user = where(email: auth.info.email).first
        return_user.provider = auth.provider
        return_user.uid = auth.uid
      else
        return_user = where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
          user.email = auth.info.email
          user.password = Devise.friendly_token[0, 20]
          user.name = auth.info.name
          user.phone = auth.info.phone || ""
        end
      end
      return_user
    end
  end

  def has_active_subscription?
    subscription_expires_at.present? && subscription_expires_at >= Date.today
  end

  def subscription_will_expire_soon?
    subscription_expires_at.present? &&
      subscription_expires_at <= 3.days.from_now.to_date &&
      subscription_expires_at >= Date.today
  end

  def on_trial?
    plan_name == "trial" && created_at >= 7.days.ago && !has_active_subscription?
  end

  def trial_days_left
    [ (created_at.to_date + 7.days - Date.today).to_i, 0 ].max
  end

  def has_write_access?
    has_active_subscription? || on_trial?
  end

  def superadmin?
    role == "superadmin"
  end
end

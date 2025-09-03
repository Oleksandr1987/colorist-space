class User < ApplicationRecord
  include PhoneValidator

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

  def self.from_omniauth(auth)
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

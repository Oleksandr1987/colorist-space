class Client < ApplicationRecord
  include PhoneValidator

  belongs_to :user

  has_many_attached :photos
  has_many :appointments, dependent: :destroy
  has_many :service_notes, dependent: :destroy
  has_many :client_phones, dependent: :destroy
  accepts_nested_attributes_for :client_phones, allow_destroy: true

  validates :first_name, presence: true
  validates :phone, uniqueness: {
    scope: :user_id,
    message: "Client with this phone number already exists"
  }

  validate :birthday_must_be_valid
  validate :phone_not_used_in_client_phones

  before_save :ensure_primary_phone

  scope :alphabetical, -> { order("LOWER(first_name)") }
  scope :with_phones, -> { includes(:client_phones) }

  scope :search_by_name, ->(query) {
    q = "%#{query.to_s.downcase}%"
    table = arel_table

    where(
      table[:first_name].lower.matches(q)
        .or(table[:last_name].lower.matches(q))
    )
  }

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def attach_photos(files)
    photos.attach(files) if files.present?
  end

  def delete_photo(photo_id)
    photos.find(photo_id).purge
  end

  def delete_all_photos
    photos.purge
  end

  def self.resolve_for_appointment(user:, full_name:, phone:)
    normalized_phone = PhoneValidator.normalize(phone)

    first_name, last_name =
      full_name.to_s.strip.split(/\s+/, 2)

    return nil if first_name.blank?

    if normalized_phone.present?
      client = user.clients.find_by(phone: normalized_phone)
      return client if client
    end

    client = user.clients.find_by(
      first_name: first_name,
      last_name: last_name.to_s
    )

    if client
      if client.phone.blank? &&
        normalized_phone.present?
        client.update(phone: normalized_phone)
      end
      return client
    end

    user.clients.create!(
      first_name: first_name,
      last_name: last_name.to_s,
      phone: normalized_phone
    )
  end

  def decorated_photos
    photos.map { |p| PhotoDecorator.decorate(p) }
  end

  def make_primary!(new_phone)
    transaction do
      client_phones.create!(phone: phone)

      update!(phone: new_phone)

      client_phones.where(phone: new_phone).destroy_all
    end
  end

  def style_appointments
    appointments.for_styles
  end

  private

  def birthday_must_be_valid
    return if birthday.blank?

    month, day = birthday.split("-").map(&:to_i)

    Date.new(2000, month, day)
  rescue Date::Error
    errors.add(:birthday, :invalid)
  end

  def ensure_primary_phone
    if phone.blank? && client_phones.any?
      self.phone = client_phones.first.phone
      client_phones.first.mark_for_destruction
    end
  end

  def phone_not_used_in_client_phones
    return if phone.blank?

    if ClientPhone.where(user_id: user_id)
                  .where.not(client_id: id)
                  .exists?(phone: phone)
      errors.add(:phone, "already exists as additional phone")
    end
  end
end

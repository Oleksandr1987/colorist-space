class Client < ApplicationRecord
  include PhoneValidator

  belongs_to :user

  has_many_attached :photos
  has_many :appointments, dependent: :destroy
  has_many :service_notes, dependent: :destroy
  has_many :client_phones, dependent: :destroy
  accepts_nested_attributes_for :client_phones, allow_destroy: true

  validates :first_name, :last_name, presence: true
  validates :phone, uniqueness: {
    scope: :user_id,
    message: "Client with this phone number already exists"
  }

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

  def self.find_or_create_by_full_name(user:, full_name:, phone:)
    first_name, last_name = full_name.to_s.split(/\s+/, 2)
    normalized_phone = PhoneValidator.normalize(phone)

    return nil if first_name.blank?

    client = user.clients.find_by(first_name: first_name, last_name: last_name)
    return client if client

    user.clients.create!(
      first_name: first_name,
      last_name: last_name.presence || "",
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

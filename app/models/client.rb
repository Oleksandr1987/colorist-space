class Client < ApplicationRecord
  include PhoneValidator

  belongs_to :user

  has_many_attached :photos
  has_many :appointments, dependent: :destroy
  has_many :service_notes, dependent: :destroy
  has_many :client_phones, dependent: :destroy

  accepts_nested_attributes_for :client_phones, allow_destroy: true

  validates :first_name, presence: true
  validates :phone, uniqueness: { scope: :user_id, message: :client_already_exists }

  validate :birthday_must_be_valid
  validate :full_name_must_be_unique
  validate :phone_not_used_in_client_phones

  before_save :ensure_primary_phone

  scope :alphabetical, -> { order("LOWER(first_name)") }
  scope :with_phones, -> { includes(:client_phones) }
  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  scope :search_by_name, ->(query) {
    q = "%#{query.to_s.downcase}%"
    table = arel_table

    where(table[:first_name].lower.matches(q).or(table[:last_name].lower.matches(q)))
  }

  scope :with_name, ->(first_name, last_name) {
    where("LOWER(TRIM(first_name)) = ?", first_name.to_s.strip.downcase)
      .where("LOWER(TRIM(COALESCE(last_name, ''))) = ?", last_name.to_s.strip.downcase)
  }

  def self.find_existing(user:, first_name:, last_name:, phone:)
    normalized_phone = PhoneValidator.normalize(phone)

    if normalized_phone.present?
      client = user.clients.find_by(phone: normalized_phone)
      return client if client

      client = user.clients.joins(:client_phones).find_by(client_phones: { phone: normalized_phone })
      return client if client
    end

    user.clients.with_name(first_name, last_name).first
  end

  def self.resolve_for_appointment(user:, full_name:, phone:)
    normalized_phone = PhoneValidator.normalize(phone)
    first_name, last_name = full_name.to_s.strip.split(/\s+/, 2)

    return nil if first_name.blank?

    client = find_existing(user: user, first_name: first_name, last_name: last_name, phone: normalized_phone)

    return client.tap(&:restore!) if client

    user.clients.create!(first_name: first_name, last_name: last_name.to_s, phone: normalized_phone)
  end

  def archive!
    transaction do
      appointments.future.destroy_all
      update!(archived_at: Time.current)
    end
  end

  def archived?
    archived_at.present?
  end

  def restore!
    update!(archived_at: nil) if archived?
  end

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
  rescue Date::Error, TypeError, ArgumentError
    errors.add(:birthday, :invalid)
  end

  def full_name_must_be_unique
    return if first_name.blank? || user_id.blank?

    duplicate = user.clients.with_name(first_name, last_name).where.not(id: id).exists?

    errors.add(:first_name, :client_already_exists) if duplicate
  end

  def ensure_primary_phone
    if phone.blank? && client_phones.any?
      self.phone = client_phones.first.phone
      client_phones.first.mark_for_destruction
    end
  end

  def phone_not_used_in_client_phones
    return if phone.blank? || user_id.blank?

    duplicate = ClientPhone
      .where(user_id: user_id, phone: phone)
      .where.not(client_id: id)
      .exists?

    return unless duplicate

    errors.add(:phone, :client_already_exists)
  end
end

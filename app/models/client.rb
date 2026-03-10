class Client < ApplicationRecord
  include PhoneValidator

  belongs_to :user

  has_many_attached :photos
  has_many :appointments, dependent: :destroy
  has_many :service_notes, dependent: :destroy

  validates :first_name, :last_name, presence: true

  scope :alphabetical, -> { order("LOWER(first_name)") }

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
    first_name, last_name = full_name.to_s.strip.split(" ", 2)

    return nil if first_name.blank?

    client = user.clients.find_by(
      first_name: first_name,
      last_name: last_name
    )

    return client if client

    user.clients.create!(
      first_name: first_name,
      last_name: last_name,
      phone: phone
    )
  end

  def decorated_photos
    photos.map { |p| PhotoDecorator.decorate(p) }
  end
end

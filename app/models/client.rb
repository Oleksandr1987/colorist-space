class Client < ApplicationRecord
  include PhoneValidator

  belongs_to :user
  has_many_attached :photos
  has_many :appointments, dependent: :destroy
  has_many :service_notes, dependent: :destroy

  validates :first_name, :last_name, presence: true

  scope :search, ->(query) {
    where("LOWER(first_name) LIKE ? OR LOWER(last_name) LIKE ?", "#{query.downcase}%", "#{query.downcase}%")
  }

  scope :alphabetical, -> { order("LOWER(first_name)") }

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def self.find_or_create_by_full_name(user:, full_name:, phone:)
    first_name, last_name = full_name.to_s.strip.split(" ", 2)

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
end

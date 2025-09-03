class Client < ApplicationRecord
  include PhoneValidator

  belongs_to :user
  has_many_attached :photos
  has_many :appointments, dependent: :destroy

  validates :first_name, :last_name, presence: true

  scope :search, ->(query) {
    where("LOWER(first_name) LIKE ? OR LOWER(last_name) LIKE ?", "#{query.downcase}%", "#{query.downcase}%")
  }

  scope :alphabetical, -> { order("LOWER(first_name)") }

  def full_name
    "#{first_name} #{last_name}".strip
  end
end

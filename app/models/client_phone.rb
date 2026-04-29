class ClientPhone < ApplicationRecord
  include PhoneValidator

  belongs_to :client

  validates :phone, uniqueness: true
end

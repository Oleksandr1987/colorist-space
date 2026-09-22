class WayforpayEvent < ApplicationRecord
  validates :fingerprint, :merchant_account, :order_reference, presence: true
end

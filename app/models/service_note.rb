class ServiceNote < ApplicationRecord
  belongs_to :user
  belongs_to :client
  belongs_to :appointment, optional: true

  has_many_attached :photos
  has_many :formula_steps, dependent: :destroy

  accepts_nested_attributes_for :formula_steps, allow_destroy: true

  scope :for_client, ->(client_id) { where(client_id: client_id).order(created_at: :desc) }

  before_validation :set_price_from_appointment, if: -> { appointment.present? && price.blank? }

  def short_title
    label = case service_type
            when "haircut" then "Стрижка"
            when "coloring" then "Фарбування"
            when "care" then "Догляд"
            else service_type.to_s.capitalize
            end
  end

  private

  def set_price_from_appointment
    self.price = appointment.total_price
  end
end

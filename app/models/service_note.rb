class ServiceNote < ApplicationRecord
  belongs_to :user
  belongs_to :client
  belongs_to :appointment

  has_many :service_note_services, dependent: :destroy
  has_many :services, through: :service_note_services
  has_many :formula_charges, dependent: :nullify
  has_many :formula_steps, dependent: :destroy, inverse_of: :service_note
  has_many :haircut_steps, dependent: :destroy, inverse_of: :service_note
  has_many :care_product_stock_movements, dependent: :nullify
  has_many :care_product_sales, dependent: :nullify

  has_many_attached :photos

  accepts_nested_attributes_for :formula_steps, allow_destroy: true
  accepts_nested_attributes_for :haircut_steps, allow_destroy: true, reject_if: :reject_empty_haircut_step?

  validates :appointment_id, uniqueness: true
  validate :care_products_stock_available
  validate :care_products_are_active_for_stock_increase

  scope :for_client, ->(client_id) {
    where(client_id: client_id).order(created_at: :desc)
  }

  before_validation :set_price_from_services
  before_validation :copy_notes_from_appointment, on: :create

  after_save :sync_appointment_services
  after_save :sync_appointment_notes

  after_create :create_care_product_sales
  after_update :sync_care_product_sales, if: :saved_change_to_care_products?

  def decorated_photos
    photos.map { |photo| PhotoDecorator.decorate(photo) }
  end

  def service_names
    services.map(&:subtype).join(" + ")
  end

  def all_services
    return services if services.any?
    return appointment.services if appointment&.services&.any?

    Service.none
  end

  def developer_total_amount
    formula_steps.sum(&:oxidant_amount)
  end

  def developer_total_price
    formula_steps.sum(&:oxidant_total_price)
  end

  def formula_ingredients_total_price
    formula_steps.sum do |step|
      step.colors_total_price + step.oxidant_total_price
    end
  end

  def care_products_income
    return 0 unless care_products.is_a?(Array)

    care_products.sum do |item|
      item["price"].to_f * item["qty"].to_i
    end
  end

  def care_products_cost
    return 0 unless care_products.is_a?(Array)

    care_products.sum do |item|
      item["purchase_price"].to_f * item["qty"].to_i
    end
  end

  def care_products_total
    care_products_income
  end

  def services_total
    return 0 unless appointment.present?

    appointment.appointment_services_relations.sum(:price)
  end

  def final_price
    services_total +
      formula_ingredients_total_price +
      care_products_income
  end

  def appointment_date
    appointment.appointment_date
  end

  def main_photo
    return if main_photo_id.blank?

    photos.attachments.find_by(id: main_photo_id)
  end

  def main_photo?(photo)
    main_photo_id == photo.id
  end

  def display_photo
    main_photo || photos.first
  end

  def ordered_photos
    attachments = photos.attachments.to_a

    return attachments if main_photo_id.blank?

    attachments.sort_by do |photo|
      photo.id == main_photo_id ? 0 : 1
    end
  end

  private

  def set_price_from_services
    return if price.present?
    return if services.empty?

    self.price = services.sum(&:price)
  end

  def copy_notes_from_appointment
    return if notes.present?
    return unless appointment&.notes.present?

    self.notes = appointment.notes
  end

  def sync_appointment_services
    return unless appointment.present?
    return if services.empty?

    appointment.sync_services_with_prices!(services.map(&:id))
  end

  def sync_appointment_notes
    return unless appointment.present?
    return if appointment.notes == notes

    appointment.update_column(:notes, notes)
  end

  def create_care_product_sales
    return unless care_products.is_a?(Array)

    care_products.each do |item|
      product = user.care_products.find_by(id: item["care_product_id"])

      next unless product

      quantity = item["qty"].to_i

      next unless quantity.positive?

      CareProducts::Sell.new(
        user: user,
        care_product: product,
        quantity: quantity,
        unit_price: item["price"],
        sold_on: appointment.appointment_date,
        service_note: self
      ).call
    end
  end

  def sync_care_product_sales
    CareProducts::SyncServiceNoteSales.new(service_note: self).call
  end

  def care_products_stock_available
    return unless care_products.is_a?(Array)

    care_products.each do |item|
      product = user.care_products.find_by(id: item["care_product_id"])

      next unless product

      requested_qty = item["qty"].to_i

      available_qty = available_stock_for(product)

      if requested_qty > available_qty
        errors.add(:base, "#{product.name}: only #{available_qty} left in stock")
      end
    end
  end

  def care_products_are_active_for_stock_increase
    return unless care_products.is_a?(Array)

    care_products.each do |item|
      product = user.care_products.find_by(id: item["care_product_id"])

      next unless product

      requested_qty = item["qty"].to_i
      previous_qty = previous_care_product_quantity(product)

      next unless requested_qty > previous_qty

      if product.deleted?
        errors.add(:base, I18n.t("care_products.errors.deleted_product"))
      elsif product.archived?
        errors.add(:base, I18n.t("care_products.errors.archived_product"))
      end
    end
  end

  def previous_care_product_quantity(product)
    Array(attribute_in_database("care_products"))
      .find { |item| item["care_product_id"].to_s == product.id.to_s }
      &.dig("qty")
      .to_i
  end

  def available_stock_for(product)
    product.stock_quantity.to_i + previous_care_product_quantity(product)
  end

  def reject_empty_haircut_step?(attrs)
    attrs.except("_destroy", "id").values.all?(&:blank?)
  end
end

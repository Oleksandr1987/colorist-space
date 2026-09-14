class ServiceNote < ApplicationRecord
  belongs_to :user
  belongs_to :client
  belongs_to :appointment

  has_many :service_note_services, dependent: :destroy
  has_many :services, through: :service_note_services
  has_many :formula_steps, dependent: :destroy, inverse_of: :service_note
  has_many :haircut_steps, dependent: :destroy, inverse_of: :service_note

  has_many_attached :photos

  accepts_nested_attributes_for :formula_steps, allow_destroy: true
  accepts_nested_attributes_for :haircut_steps, allow_destroy: true, reject_if: :reject_empty_haircut_step?

  validates :appointment_id, uniqueness: true
  validate :must_have_services
  validate :care_products_stock_available

  scope :for_client, ->(client_id) {
    where(client_id: client_id)
      .order(created_at: :desc)
  }

  before_validation :set_price_from_services
  before_validation :copy_notes_from_appointment, on: :create

  after_save :sync_appointment_services
  after_save :sync_appointment_notes

  after_create :decrease_care_products_stock

  after_update :sync_care_products_stock, if: :saved_change_to_care_products?

  after_destroy :restore_care_products_stock

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
      step.colors_total_price +
        step.oxidant_total_price
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

  def must_have_services
    return if services.any?
    return if appointment&.services&.any?

    errors.add(:base, I18n.t("service_notes.errors.services_required"))
  end

  def decrease_care_products_stock
    return unless care_products.is_a?(Array)

    care_products.each do |item|
      product = CareProduct.find_by(id: item["care_product_id"])

      next unless product

      qty = item["qty"].to_i

      next if qty <= 0

      current_stock = product.stock_quantity.to_i

      product.update!(stock_quantity: [ current_stock - qty, 0 ].max)
    end
  end

  def restore_care_products_stock
    return unless care_products.is_a?(Array)

    care_products.each do |item|
      product = CareProduct.find_by(id: item["care_product_id"])

      next unless product

      qty = item["qty"].to_i

      next if qty <= 0

      product.increment!(:stock_quantity, qty)
    end
  end

  def sync_care_products_stock
    old_products = care_products_before_last_save || []

    new_products = care_products || []

    old_hash =
      old_products.index_by do |item|
        item["care_product_id"].to_s
      end

    new_hash =
      new_products.index_by do |item|
        item["care_product_id"].to_s
      end

    product_ids = old_hash.keys | new_hash.keys

    product_ids.each do |product_id|
      product = CareProduct.find_by(id: product_id)

      next unless product

      old_qty = old_hash[product_id]&.dig("qty").to_i

      new_qty = new_hash[product_id]&.dig("qty").to_i

      diff = new_qty - old_qty

      next if diff.zero?

      if diff.positive?
        product.decrement!(:stock_quantity, diff)
      else
        product.increment!(:stock_quantity, diff.abs)
      end
    end
  end

  def care_products_stock_available
    return unless care_products.is_a?(Array)

    care_products.each do |item|
      product = CareProduct.find_by(id: item["care_product_id"])

      next unless product

      requested_qty = item["qty"].to_i

      available_qty = available_stock_for(product)

      if requested_qty > available_qty
        errors.add(:base, "#{product.name}: only #{available_qty} left in stock")
      end
    end
  end

  def available_stock_for(product)
    current_qty =
      Array(attribute_in_database("care_products"))
        .find do |item|
          item["care_product_id"].to_s == product.id.to_s
        end
        &.dig("qty")
        .to_i

    product.stock_quantity.to_i + current_qty
  end

  def reject_empty_haircut_step?(attrs)
    attrs.except("_destroy", "id").values.all?(&:blank?)
  end
end

module PhoneValidator
  extend ActiveSupport::Concern

  included do
    before_validation :normalize_phone

    validates :phone,
      presence: true,
      format: {
        with: /\A\+380\d{9}\z/,
        message: :invalid_phone
      }
  end

  def self.normalize(value)
    return nil if value.blank?

    digits = value.to_s.gsub(/\D/, "")

    national_number =
      case digits
      when /\A380(\d{9})\z/
        Regexp.last_match(1)
      when /\A0(\d{9})\z/
        Regexp.last_match(1)
      when /\A(\d{9})\z/
        Regexp.last_match(1)
      else
        return value
      end

    "+380#{national_number}"
  end

  private

  def normalize_phone
    return if phone.blank?

    self.phone = PhoneValidator.normalize(phone)
  end
end

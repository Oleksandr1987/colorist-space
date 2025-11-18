module PhoneValidator
  extend ActiveSupport::Concern

  included do
    before_validation :normalize_phone

    validates :phone, presence: true,
                      format: {
                        with: /\A\+380\d{9}\z/,
                        message: 'must start with +380 and contain 9 digits after, e.g. +380123456789'
                      }
  end

  def self.normalize(value)
    return nil if value.blank?

    digits = value.to_s.gsub(/\D/, '')

    if digits.start_with?('0')
      "+380#{digits[1..]}"
    elsif digits.start_with?('380')
      "+#{digits}"
    elsif digits.start_with?('8') && digits.size == 11
      "+3#{digits}"
    else
      "+#{digits}"
    end
  end

  private

  def normalize_phone
    return if phone.blank?
    self.phone = PhoneValidator.normalize(phone)
  end
end

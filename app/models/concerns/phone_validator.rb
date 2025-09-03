module PhoneValidator
  extend ActiveSupport::Concern

  included do
    before_validation :normalize_phone

    validates :phone, presence: true,
                      format: {
                        with: /\A\+380\d{9}\z/,
                        message: 'must start with +380 and contain 9 digits after, e.g. +380931234567'
                      }
  end

  private

  def normalize_phone
    return if phone.blank?

    # Видаляємо всі символи, крім цифр
    digits = phone.gsub(/\D/, '')

    # Якщо починається з 0 → замінюємо на +380
    if digits.start_with?('0')
      self.phone = "+380#{digits[1..]}"
    elsif digits.start_with?('380')
      self.phone = "+#{digits}"
    elsif digits.start_with?('8') && digits.size == 11 # старі формати типу 8093...
      self.phone = "+3#{digits}"
    else
      self.phone = "+#{digits}"
    end
  end
end

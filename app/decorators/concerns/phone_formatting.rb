module PhoneFormatting
  private

  def format_phone(phone)
    return if phone.blank?

    digits = phone.to_s.gsub(/\D/, "")
    return phone unless digits.match?(/\A380\d{9}\z/)

    national = digits.delete_prefix("380")

    "+380 (#{national[0, 2]}) #{national[2, 3]} #{national[5, 2]} #{national[7, 2]}"
  end
end

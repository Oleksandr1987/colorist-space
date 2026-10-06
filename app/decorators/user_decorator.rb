class UserDecorator < Draper::Decorator
  include PhoneFormatting

  delegate_all

  def formatted_phone
    format_phone(object.phone)
  end

  def display_value(field)
    return formatted_phone if field.to_s == "phone"

    object.public_send(field)
  end
end

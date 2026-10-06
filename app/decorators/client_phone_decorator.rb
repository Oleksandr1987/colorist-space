class ClientPhoneDecorator < Draper::Decorator
  include PhoneFormatting

  delegate_all

  def formatted_phone
    format_phone(object.phone)
  end
end

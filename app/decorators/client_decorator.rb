class ClientDecorator < Draper::Decorator
  delegate_all

  def formatted_birthday
    return if object.birthday.blank?

    month, day = object.birthday.split("-").map(&:to_i)

    date = Date.new(2000, month, day)

    I18n.l(date, format: :birthday)
  end
end

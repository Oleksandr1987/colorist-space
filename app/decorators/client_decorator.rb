class ClientDecorator < Draper::Decorator
  delegate_all

  def formatted_birthday
    return if object.birthday.blank?

    month, day = object.birthday.split("-")

    month_name =
      Date::MONTHNAMES[month.to_i]

    "#{day} #{month_name}"
  end
end

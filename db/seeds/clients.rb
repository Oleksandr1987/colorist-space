# frozen_string_literal: true

puts "🌱 Seeding clients..."

user = User.find_by!(email: "demo@colorist.space")

first_names = %w[
  Amelia
  Benjamin
  Charlotte
  Daniel
  Emma
  Felix
  Grace
  Henry
  Isabella
  Jack
  Katherine
  Liam
  Mia
  Noah
  Olivia
  Peter
  Quinn
  Ruby
  Sophia
  Thomas
  Uma
  Victoria
  William
  Xenia
  Yana
  Zoe
]

first_names.each_with_index do |first_name, index|
  phone = format("+38050000%04d", index + 1)

  client = user.clients.find_or_initialize_by(phone: phone)

  client.assign_attributes(
    first_name: first_name,
    last_name: "Demo"
  )

  client.save!
end

puts "✅ Clients seeded"

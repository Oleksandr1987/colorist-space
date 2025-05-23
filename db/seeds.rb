# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
puts "🌱 Seeding default services..."

user = User.find(1)

default_services = [
  # Haircuts
  { category: "Haircut",  subtype: "Short haircut with clippers", price: 300 },
  { category: "Haircut",  subtype: "Long haircut with scissors", price: 500 },
  { category: "Haircut",  subtype: "Fade haircut", price: 400 },
  { category: "Haircut",  subtype: "Children's haircut", price: 250 },

  # Coloring
  { category: "Coloring", subtype: "Full hair coloring", price: 1500 },
  { category: "Coloring", subtype: "Roots refresh", price: 1000 },
  { category: "Coloring", subtype: "Balayage", price: 1800 },
  { category: "Coloring", subtype: "Ombre", price: 1700 },

  # Styling
  { category: "Styling",  subtype: "Evening style", price: 700 },
  { category: "Styling",  subtype: "Everyday styling", price: 400 },
  { category: "Styling",  subtype: "Wedding styling", price: 1200 },

  # Treatment
  { category: "Treatment", subtype: "Keratin treatment", price: 2200 },
  { category: "Treatment", subtype: "Deep hydration", price: 1000 },
  { category: "Treatment", subtype: "Botox for hair", price: 1800 }
]

default_services.each do |attrs|
  name = "#{attrs[:category]}: #{attrs[:subtype]}"
  Service.find_or_create_by!(attrs.merge(user_id: user.id, name: name))
end

puts "✅ Done seeding default services for #{user.name}."


puts "🌱 Seeding clients for user..."

alphabet = ('A'..'Z').to_a
existing_clients = user.clients.to_a

alphabet.each do |letter|
  existing_for_letter = existing_clients.select { |client| client.first_name.starts_with?(letter) }

  if existing_for_letter.count < 15
    (15 - existing_for_letter.count).times do
      FactoryBot.create(:client,
        user: user,
        first_name: "#{letter}#{Faker::Name.first_name}",
        last_name: Faker::Name.last_name
      )
    end
  end
end

puts "✅ Done creating test clients."

puts "🌱 Seeding sample expenses by month..."

require 'faker'

categories = Expense::CATEGORIES
today = Date.today

12.times do |i|
  month_date = today << i # віднімаємо i місяців назад
  start_date = month_date.beginning_of_month
  end_date = [month_date.end_of_month, today].min # якщо це поточний місяць — обмежимо сьогоднішнім днем

  20.times do
    Expense.create!(
      user: user,
      category: categories.sample,
      amount: rand(100..2500),
      spent_on: rand(start_date..end_date),
      note: Faker::Commerce.product_name
    )
  end
end

puts "✅ Done creating expenses."

puts "🌱 Seeding appointments with income data..."

require 'faker'

user = User.find(1)
clients = user.clients.to_a
services_by_type = user.services.group_by(&:service_type)

main_services = services_by_type["service"] || []
other_services = (services_by_type["preparation"] || []) + (services_by_type["care_product"] || [])

if main_services.empty?
  puts "❌ No main services found. Skipping appointment seeding."
else
  # Генеруємо 100 записів рівномірно розподілених по останніх 6 місяцях
  200.times do
    client = clients.sample
    days_ago = rand(0..180)
    date = Date.today - days_ago
    time = Time.zone.parse("#{rand(9..17)}:#{[0, 30].sample}")

    appt = user.appointments.build(
      client: client,
      appointment_date: date,
      appointment_time: time
    )

    # Додаємо 1 обов’язковий main service + 0-2 додаткові
    selected_main = main_services.sample
    selected_others = other_services.sample(rand(0..2))

    appt.services << selected_main
    appt.services << selected_others

    if appt.save
      puts "✅ Created appointment for #{client.full_name} on #{date} at #{time.strftime('%H:%M')}"
    else
      puts "⚠️ Failed for #{client.full_name}: #{appt.errors.full_messages.join(', ')}"
    end
  end

  puts "✅ Done creating appointments for analytics testing."
end

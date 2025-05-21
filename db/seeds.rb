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

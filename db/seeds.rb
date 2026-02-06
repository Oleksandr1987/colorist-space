# db/seeds.rb
#
# This file should ensure the existence of records required to run the application.
# It must be idempotent and safe to run multiple times.
#
# IMPORTANT:
# - No assumptions about existing records (NO find(1))
# - No FactoryBot usage
# - Heavy demo data only in development

require "faker"

puts "🌱 Running seeds for #{Rails.env} environment..."

# -------------------------------------------------------------------
# Base / demo user (used only in development)
# -------------------------------------------------------------------

unless Rails.env.development?
  puts "ℹ️ Skipping demo seeds outside development environment"
  return
end

demo_user = User.find_or_create_by!(email: "demo@colorist.space") do |u|
  u.name = "Demo User"
  u.phone = "+380500000000"
  u.password = "Password123!"
  u.tos_agreement = true
end

puts "👤 Demo user ready: #{demo_user.email}"

# -------------------------------------------------------------------
# Default services
# -------------------------------------------------------------------

puts "🌱 Seeding default services..."

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
  Service.find_or_create_by!(
    user: demo_user,
    name: "#{attrs[:category]}: #{attrs[:subtype]}"
  ) do |service|
    service.assign_attributes(attrs)
  end
end

puts "✅ Default services seeded"

# -------------------------------------------------------------------
# Clients (A–Z, up to 15 per letter)
# -------------------------------------------------------------------

puts "🌱 Seeding clients..."

alphabet = ("A".."Z").to_a

alphabet.each do |letter|
  existing_count =
    demo_user.clients.where("first_name LIKE ?", "#{letter}%").count

  next if existing_count >= 15

  (15 - existing_count).times do
    Client.create!(
      user: demo_user,
      first_name: "#{letter}#{Faker::Name.first_name}",
      last_name: Faker::Name.last_name,
      phone: Faker::PhoneNumber.cell_phone
    )
  end
end

puts "✅ Clients seeded"

# -------------------------------------------------------------------
# Expenses (last 12 months)
# -------------------------------------------------------------------

puts "🌱 Seeding expenses..."

categories = Expense::CATEGORIES
today = Date.today

12.times do |i|
  month_date = today << i
  start_date = month_date.beginning_of_month
  end_date = [month_date.end_of_month, today].min

  20.times do
    Expense.create!(
      user: demo_user,
      category: categories.sample,
      amount: rand(100..2500),
      spent_on: rand(start_date..end_date),
      note: Faker::Commerce.product_name
    )
  end
end

puts "✅ Expenses seeded"

# -------------------------------------------------------------------
# Appointments (past 6 months)
# -------------------------------------------------------------------

puts "🌱 Seeding appointments (past)..."

clients = demo_user.clients.to_a
services_by_type = demo_user.services.group_by(&:service_type)

main_services = services_by_type["service"] || []
other_services =
  (services_by_type["preparation"] || []) +
  (services_by_type["care_product"] || [])

if main_services.empty?
  puts "⚠️ No main services found, skipping appointment seeding"
else
  200.times do
    client = clients.sample
    date = Date.today - rand(0..180)
    time = Time.zone.parse("#{rand(9..17)}:#{[0, 30].sample}")

    appointment = demo_user.appointments.build(
      client: client,
      appointment_date: date,
      appointment_time: time
    )

    appointment.services << main_services.sample
    appointment.services << other_services.sample(rand(0..2))

    if appointment.save
      appointment.update_column(:service_name, appointment.combined_service_name)
    end
  end

  puts "✅ Past appointments seeded"
end

# -------------------------------------------------------------------
# Future appointments (calendar UI)
# -------------------------------------------------------------------

puts "🌱 Seeding future appointments..."

(start_date = Date.today)..(end_date = Date.today + 4.months).each do |date|
  rand(3..4).times do
    client = clients.sample
    hour = rand(9..16)
    minute = [0, 15, 30, 45].sample
    time = Time.zone.parse("#{hour}:#{minute}")

    appointment = demo_user.appointments.build(
      client: client,
      appointment_date: date,
      appointment_time: time
    )

    appointment.services << main_services.sample
    appointment.services << other_services.sample(rand(0..2))

    if appointment.save
      appointment.update_column(:service_name, appointment.combined_service_name)
    end
  end
end

puts "✅ Future appointments seeded"
puts "🎉 Seeding completed successfully"

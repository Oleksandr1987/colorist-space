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
# Formula Products
# -------------------------------------------------------------------

puts "🌱 Seeding formula products..."

formula_products = [

  # COLORS

  {
    category: "color",
    brand: "Wella",
    name: "7/43",
    unit: "g",
    price_per_unit: 15
  },

  {
    category: "color",
    brand: "Schwarzkopf",
    name: "8/43",
    unit: "g",
    price_per_unit: 25
  },

  {
    category: "color",
    brand: "Echosline",
    name: "9/43",
    unit: "g",
    price_per_unit: 16
  },

  {
    category: "color",
    brand: "Lakme",
    name: "6N",
    unit: "g",
    price_per_unit: 14
  },

  {
    category: "color",
    brand: "Matrix",
    name: "8A",
    unit: "g",
    price_per_unit: 14
  },

  {
    category: "color",
    brand: "Londa",
    name: "7/1",
    unit: "g",
    price_per_unit: 13
  },

  # OXIDANTS

  {
    category: "oxidant",
    brand: "Wella",
    name: "1.9%",
    unit: "ml",
    price_per_unit: 1.2
  },

  {
    category: "oxidant",
    brand: "Wella",
    name: "3%",
    unit: "ml",
    price_per_unit: 1.3
  },

  {
    category: "oxidant",
    brand: "Nouvelle",
    name: "6%",
    unit: "ml",
    price_per_unit: 1.5
  },

  {
    category: "oxidant",
    brand: "Inebrya",
    name: "9%",
    unit: "ml",
    price_per_unit: 1.8
  },

  {
    category: "oxidant",
    brand: "Matrix",
    name: "3%",
    unit: "ml",
    price_per_unit: 1.4
  },

  {
    category: "oxidant",
    brand: "Previa",
    name: "6%",
    unit: "ml",
    price_per_unit: 1.6
  }
]

formula_products.each do |attrs|
  FormulaProduct.find_or_create_by!(
    user: demo_user,
    category: attrs[:category],
    brand: attrs[:brand],
    name: attrs[:name]
  ) do |product|
    product.unit = attrs[:unit]
    product.price_per_unit = attrs[:price_per_unit]
  end
end

puts "✅ Formula products seeded"

# -------------------------------------------------------------------
# Care Products (user 1)
# -------------------------------------------------------------------

puts "🌱 Seeding care products..."

user = User.find_by(email: "solovij1987@gmail.com")

if user.present?
  care_products = [
    {
      brand: "Olaplex",
      name: "No.4 Bond Maintenance Shampoo",
      category: "Shampoo",
      purchase_price: 650,
      sale_price: 900,
      stock_quantity: 8
    },
    {
      brand: "Olaplex",
      name: "No.5 Bond Maintenance Conditioner",
      category: "Conditioner",
      purchase_price: 700,
      sale_price: 950,
      stock_quantity: 6
    },
    {
      brand: "Kérastase",
      name: "Nutritive Mask",
      category: "Mask",
      purchase_price: 1200,
      sale_price: 1600,
      stock_quantity: 5
    },
    {
      brand: "Kérastase",
      name: "Elixir Ultime Oil",
      category: "Oil",
      purchase_price: 1400,
      sale_price: 1900,
      stock_quantity: 4
    },
    {
      brand: "L'Oréal Professionnel",
      name: "Absolut Repair Shampoo",
      category: "Shampoo",
      purchase_price: 500,
      sale_price: 750,
      stock_quantity: 10
    },
    {
      brand: "L'Oréal Professionnel",
      name: "Absolut Repair Mask",
      category: "Mask",
      purchase_price: 650,
      sale_price: 950,
      stock_quantity: 7
    },
    {
      brand: "Davines",
      name: "OI All In One Milk",
      category: "Spray",
      purchase_price: 800,
      sale_price: 1200,
      stock_quantity: 6
    },
    {
      brand: "Davines",
      name: "OI Oil",
      category: "Oil",
      purchase_price: 950,
      sale_price: 1400,
      stock_quantity: 5
    },
    {
      brand: "Moroccanoil",
      name: "Treatment Original",
      category: "Oil",
      purchase_price: 1000,
      sale_price: 1500,
      stock_quantity: 6
    },
    {
      brand: "Redken",
      name: "Acidic Bonding Concentrate",
      category: "Treatment",
      purchase_price: 900,
      sale_price: 1300,
      stock_quantity: 4
    }
  ]

  care_products.each do |attrs|
    CareProduct.find_or_create_by!(
      user: user,
      brand: attrs[:brand],
      name: attrs[:name]
    ) do |product|
      product.category = attrs[:category]
      product.purchase_price = attrs[:purchase_price]
      product.sale_price = attrs[:sale_price]
      product.stock_quantity = attrs[:stock_quantity]
    end
  end

  puts "✅ Care products seeded"
end

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
  end_date = [ month_date.end_of_month, today ].min

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
  services = demo_user.services.to_a

if services.empty?
  puts "⚠️ No services found, skipping appointment seeding"
else
  200.times do
    client = clients.sample
    date = Date.today - rand(0..180)
    time = Time.zone.parse("#{rand(9..17)}:#{[ 0, 30 ].sample}")

    appointment = demo_user.appointments.build(
      client: client,
      appointment_date: date,
      appointment_time: time
    )

    appointment.services << services.sample

    if appointment.save
      appointment.update_column(
        :service_name,
        appointment.combined_service_name
      )
    end
  end

  puts "✅ Past appointments seeded"
end

# -------------------------------------------------------------------
# Future appointments (calendar UI)
# -------------------------------------------------------------------

puts "🌱 Seeding future appointments..."

start_date = Date.today
end_date = Date.today + 4.months

(start_date..end_date).each do |date|
  rand(3..4).times do
    client = clients.sample
    hour = rand(9..16)
    minute = [ 0, 15, 30, 45 ].sample

    time = Time.zone.parse("#{hour}:#{minute}")

    appointment = demo_user.appointments.build(
      client: client,
      appointment_date: date,
      appointment_time: time
    )

    appointment.services << services.sample

    if appointment.save
      appointment.update_column(
        :service_name,
        appointment.combined_service_name
      )
    end
  end
end

puts "✅ Future appointments seeded"
puts "🎉 Seeding completed successfully"

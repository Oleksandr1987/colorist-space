# frozen_string_literal: true

puts "🌱 Seeding services..."

user = User.find_by!(email: "demo@colorist.space")

services = [
  { category: "haircut", subtype: "Short haircut with clippers", price: 300 },
  { category: "haircut", subtype: "Long haircut with scissors", price: 500 },
  { category: "haircut", subtype: "Fade haircut", price: 400 },
  { category: "haircut", subtype: "Children's haircut", price: 250 },

  { category: "coloring", subtype: "Full hair coloring", price: 1500 },
  { category: "coloring", subtype: "Roots refresh", price: 1000 },
  { category: "coloring", subtype: "Balayage", price: 1800 },
  { category: "coloring", subtype: "Ombre", price: 1700 },

  { category: "styling", subtype: "Evening style", price: 700 },
  { category: "styling", subtype: "Everyday styling", price: 400 },
  { category: "styling", subtype: "Wedding styling", price: 1200 },

  { category: "treatment", subtype: "Keratin treatment", price: 2200 },
  { category: "treatment", subtype: "Deep hydration", price: 1000 },
  { category: "treatment", subtype: "Botox for hair", price: 1800 }
]

services.each do |attrs|
  service =
    user.services.find_or_initialize_by(
      service_type: "service",
      category: attrs[:category],
      subtype: attrs[:subtype]
    )

  service.price = attrs[:price]
  service.save!
end

puts "✅ Services seeded"

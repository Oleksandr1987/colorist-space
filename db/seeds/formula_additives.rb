
# frozen_string_literal: true

puts "🌱 Seeding formula additives..."

user = User.find_by!(email: "demo@colorist.space")

additives = [
  { brand: "Olaplex", name: "No.1 Bond Multiplier", unit: "ml", price_per_unit: 18 },
  { brand: "Olaplex", name: "No.2 Bond Perfector", unit: "ml", price_per_unit: 12 },
  { brand: "Wella", name: "Wellaplex No.1 Bond Maker", unit: "ml", price_per_unit: 14 },
  { brand: "Wella", name: "Wellaplex No.2 Bond Stabilizer", unit: "ml", price_per_unit: 11 },
  { brand: "Schwarzkopf", name: "Fibreplex No.1 Bond Booster", unit: "ml", price_per_unit: 16 },
  { brand: "Schwarzkopf", name: "Fibreplex No.2 Bond Sealer", unit: "ml", price_per_unit: 13 },
  { brand: "L'Oréal Professionnel", name: "Smartbond Step 1", unit: "ml", price_per_unit: 15 },
  { brand: "L'Oréal Professionnel", name: "Smartbond Step 2", unit: "ml", price_per_unit: 12 },
  { brand: "Matrix", name: "Bond Ultim8 Step 1", unit: "ml", price_per_unit: 14 },
  { brand: "Matrix", name: "Bond Ultim8 Step 2", unit: "ml", price_per_unit: 10 },
  { brand: "K18", name: "Professional Molecular Repair Mist", unit: "ml", price_per_unit: 22 },
  { brand: "Echosline", name: "Echos Color Plex", unit: "ml", price_per_unit: 9 }
]

created = 0
existing = 0

additives.each do |attrs|
  product = user.formula_products.find_or_initialize_by(
    category: "additive",
    brand: attrs[:brand],
    name: attrs[:name]
  )

  if product.persisted?
    existing += 1
    next
  end

  product.unit = attrs[:unit]
  product.price_per_unit = attrs[:price_per_unit]

  product.save!
  created += 1
end

puts "✅ Formula additives seeded"
puts "   Created: #{created}"
puts "   Already existed: #{existing}"

# frozen_string_literal: true

puts "🌱 Seeding care products..."

user = User.find_by!(email: "demo@colorist.space")

care_products = [
  {
    brand: "Olaplex",
    name: "No.4 Bond Maintenance Shampoo",
    category: "shampoo",
    purchase_price: 650,
    sale_price: 900,
    stock_quantity: 8
  },
  {
    brand: "Olaplex",
    name: "No.5 Bond Maintenance Conditioner",
    category: "conditioner",
    purchase_price: 700,
    sale_price: 950,
    stock_quantity: 6
  },
  {
    brand: "Kérastase",
    name: "Nutritive Mask",
    category: "mask",
    purchase_price: 1200,
    sale_price: 1600,
    stock_quantity: 5
  },
  {
    brand: "Kérastase",
    name: "Elixir Ultime Oil",
    category: "oil",
    purchase_price: 1400,
    sale_price: 1900,
    stock_quantity: 4
  },
  {
    brand: "L'Oréal Professionnel",
    name: "Absolut Repair Shampoo",
    category: "shampoo",
    purchase_price: 500,
    sale_price: 750,
    stock_quantity: 10
  },
  {
    brand: "L'Oréal Professionnel",
    name: "Absolut Repair Mask",
    category: "mask",
    purchase_price: 650,
    sale_price: 950,
    stock_quantity: 7
  },
  {
    brand: "Davines",
    name: "OI All In One Milk",
    category: "spray",
    purchase_price: 800,
    sale_price: 1200,
    stock_quantity: 6
  },
  {
    brand: "Davines",
    name: "OI Oil",
    category: "oil",
    purchase_price: 950,
    sale_price: 1400,
    stock_quantity: 5
  },
  {
    brand: "Moroccanoil",
    name: "Treatment Original",
    category: "oil",
    purchase_price: 1000,
    sale_price: 1500,
    stock_quantity: 6
  },
  {
    brand: "Redken",
    name: "Acidic Bonding Concentrate",
    category: "treatment",
    purchase_price: 900,
    sale_price: 1300,
    stock_quantity: 4
  }
]

care_products.each do |attrs|
  normalized_brand = attrs[:brand].to_s.unicode_normalize(:nfkc).squish.downcase
  normalized_name = attrs[:name].to_s.unicode_normalize(:nfkc).squish.downcase
  normalized_category = attrs[:category].to_s.unicode_normalize(:nfkc).squish.downcase

  existing_product =
    user.care_products
        .where(deleted_at: nil)
        .find_by(
          normalized_brand: normalized_brand,
          normalized_name: normalized_name,
          normalized_category: normalized_category
        )

  next if existing_product

  CareProducts::Create.new(
    user: user,
    attributes: attrs,
    purchased_on: Date.current
  ).call
end

puts "✅ Care products seeded"

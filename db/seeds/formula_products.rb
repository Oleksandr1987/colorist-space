# -------------------------------------------------------------------
# Formula Products
# -------------------------------------------------------------------

puts "🌱 Seeding formula products..."

demo_user = User.find_by!(email: "demo@colorist.space")

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
    unit: "ml",
    price_per_unit: 14
  },
  {
    category: "color",
    brand: "Londa",
    name: "7/1",
    unit: "ml",
    price_per_unit: 13
  },

  # OXIDANTS — %

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
    unit: "g",
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
    unit: "g",
    price_per_unit: 1.8
  },

  # OXIDANTS — VOL

  {
    category: "oxidant",
    brand: "Matrix",
    name: "10 vol",
    unit: "ml",
    price_per_unit: 1.4
  },
  {
    category: "oxidant",
    brand: "Matrix",
    name: "20 vol",
    unit: "g",
    price_per_unit: 1.5
  },
  {
    category: "oxidant",
    brand: "Previa",
    name: "30 vol",
    unit: "ml",
    price_per_unit: 1.6
  },
  {
    category: "oxidant",
    brand: "Previa",
    name: "40 vol",
    unit: "g",
    price_per_unit: 1.8
  }
]

formula_products.each do |attrs|
  product =
    FormulaProduct.find_or_initialize_by(
      user: demo_user,
      category: attrs[:category],
      brand: attrs[:brand],
      name: attrs[:name]
    )

  product.unit = attrs[:unit]
  product.price_per_unit = attrs[:price_per_unit]

  product.save!
end

puts "✅ Formula products seeded"

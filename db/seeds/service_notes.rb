# frozen_string_literal: true

puts "🌱 Seeding service notes..."

user = User.find_by!(email: "demo@colorist.space")

historical_appointments =
  user.appointments
      .where(appointment_date: ..Date.current)
      .includes(:client, :services, :service_note)
      .order(:appointment_date, :appointment_time)
      .to_a

colors = user.formula_products.colors.ordered.to_a
oxidants = user.formula_products.oxidants.ordered.to_a
care_products = user.care_products.active.order(:id).to_a

raise "Demo historical appointments are missing" if historical_appointments.empty?
raise "Demo color products are missing" if colors.empty?
raise "Demo oxidants are missing" if oxidants.empty?
raise "Demo care products are missing" if care_products.empty?

historical_appointments.each_with_index do |appointment, index|
  next if appointment.service_note.present?

  services = appointment.services.to_a

  next if services.empty?

  note = ServiceNote.new(
    user: user,
    client: appointment.client,
    appointment: appointment,
    service_type: services.first.service_type,
    notes: "Demo service note #{index + 1}"
  )

note.services = services

  note.services = services

  if index % 3 == 0
    care_product = care_products[index % care_products.size]

    if care_product.stock_quantity.to_i.positive?
      note.care_products = [
        {
          "care_product_id" => care_product.id.to_s,
          "price" => care_product.sale_price.to_f,
          "purchase_price" => care_product.purchase_price.to_f,
          "qty" => 1
        }
      ]
    end
  end

  note.save!

  if index.even?
    color = colors[index % colors.size]
    oxidant = oxidants[index % oxidants.size]

    formula_step = note.formula_steps.create!(
      section: FormulaStep::SECTIONS[index % FormulaStep::SECTIONS.size],
      time: 35,
      oxidant: [
        {
          "formula_product_id" => oxidant.id.to_s,
          "amount" => 30,
          "price" => oxidant.price_per_unit.to_f,
          "ratio" => "1:1"
        }
      ]
    )

    formula_step.formula_ingredients.create!(
      formula_product: color,
      shade: color.name,
      amount: 30,
      price: color.price_per_unit
    )
  end

  if index % 4 == 0
    note.haircut_steps.create!(
      zone: HaircutStep::ZONES[index % HaircutStep::ZONES.size],
      instrument: HaircutStep::INSTRUMENTS[index % HaircutStep::INSTRUMENTS.size],
      parting: HaircutStep::PARTINGS[index % HaircutStep::PARTINGS.size],
      elevation: HaircutStep::ELEVATIONS[index % HaircutStep::ELEVATIONS.size],
      cut_type: HaircutStep::CUT_TYPES[index % HaircutStep::CUT_TYPES.size]
    )
  end
end

puts "✅ Service notes seeded"

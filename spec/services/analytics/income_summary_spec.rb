require "rails_helper"

RSpec.describe Analytics::IncomeSummary do
  subject(:summary) do
    described_class.new(user: user, from: 1.month.ago.to_date, to: Date.current, **filters)
  end

  let(:user) { create(:user) }
  let(:client) { create(:client, user: user) }
  let(:filters) { {} }

  def create_appointment(service:, time:)
    create(:appointment, user: user, client: client,
      appointment_date: Date.current,
      appointment_time: time,
      end_time: (Time.zone.parse(time) + 30.minutes).strftime("%H:%M"),
      main_service: service
    )
  end

  def create_note(appointment:, service:, care_products: [])
    note = build(:service_note, :without_services, user: user, client: client, appointment: appointment, care_products: care_products)

    note.services = [ service ]
    note.save!
    note
  end

  def sync_formula_charges(note)
    Formulas::SyncCharges.new(service_note: note.reload).call
  end

  describe "formula product filtering" do
    let(:service) { create(:service, user: user, service_type: "service", category: "coloring", subtype: "Balayage", price: 100) }
    let(:other_service) { create(:service, user: user, service_type: "service", category: "haircut", subtype: "Haircut", price: 200) }

    context "when a color ingredient is selected" do
      let(:color_product) { create(:formula_product, user: user, category: "color") }
      let(:filters) { { formula_product_ids: [ color_product.id ] } }

      before do
        appointment = create_appointment(service: service, time: "10:00")
        note = create_note(appointment: appointment, service: service)
        step = create(:formula_step, service_note: note)

        create(:formula_ingredient, formula_step: step, formula_product: color_product, amount: 10, price: 5)

        sync_formula_charges(note)
        create_appointment(service: other_service, time: "11:00")
      end

      it "includes only appointments containing the selected color" do
        expect(summary.service_income).to eq(100)
        expect(summary.formula_income).to eq(50)
        expect(summary.total_income).to eq(150)
      end
    end

    context "when an oxidant is selected" do
      let(:oxidant_product) { create(:formula_product, :oxidant, user: user) }
      let(:filters) { { formula_product_ids: [ oxidant_product.id ] } }

      before do
        appointment = create_appointment(service: service, time: "10:00")
        note = create_note(appointment: appointment, service: service)

        create(:formula_step, service_note: note,
          oxidant: [ { "formula_product_id" => oxidant_product.id, "amount" => 20, "price" => 2 } ])

        sync_formula_charges(note)
        create_appointment(service: other_service, time: "11:00")
      end

      it "includes only appointments containing the selected oxidant" do
        expect(summary.service_income).to eq(100)
        expect(summary.formula_income).to eq(40)
        expect(summary.total_income).to eq(140)
      end
    end
  end

  describe "service income" do
    let(:haircut) { create(:service, user: user, category: "haircut", subtype: "Haircut", price: 100) }
    let(:coloring) { create(:service, user: user, category: "coloring", subtype: "Coloring", price: 200) }

    before do
      create_appointment(service: haircut, time: "10:00")
      create_appointment(service: coloring, time: "11:00")
    end

    it "groups service income by category" do
      expect(summary.grouped_service_income).to eq("haircut" => 100, "coloring" => 200)
    end

    it "calculates total service income" do
      expect(summary.service_income).to eq(300)
    end

    it "filters services by category" do
      filtered = described_class.new(user: user, from: 1.month.ago.to_date, to: Date.current, service_categories: [ "haircut" ])

      expect(filtered.grouped_service_income).to eq("haircut" => 100)
      expect(filtered.service_income).to eq(100)
    end

    it "returns expanded relations for an existing category" do
      relations = summary.expanded_relations("haircut")

      expect(relations.size).to eq(1)
      expect(relations.first.service_category).to eq("haircut")
    end

    it "returns no expanded relations for an unknown category" do
      expect(summary.expanded_relations("unknown")).to be_empty
      expect(summary.expanded_relations(nil)).to be_empty
    end

    it "groups monthly income by appointment month" do
      I18n.with_locale(:en) do
        grouped = summary.monthly_income("haircut")

        expect(grouped.keys).to eq([ Date.current.strftime("%B %Y") ])
        expect(grouped.values.flatten.size).to eq(1)
      end
    end
  end

  describe "care product filtering" do
    let(:service) { create(:service, user: user, service_type: "service", category: "coloring", subtype: "Balayage", price: 100) }
    let(:other_service) { create(:service, user: user, service_type: "service", category: "haircut", subtype: "Haircut", price: 200) }
    let(:care_product) { create(:care_product, user: user) }
    let(:filters) { { care_product_ids: [ care_product.id ] } }

    before do
      appointment = create_appointment(service: service, time: "10:00")

      create_note(appointment: appointment, service: service,
        care_products: [
          { "care_product_id" => care_product.id, "name" => care_product.display_name, "price" => 50, "purchase_price" => 30, "qty" => 2 }
        ]
      )

      create_appointment(service: other_service, time: "11:00")
    end

    it "includes only appointments containing the selected care product" do
      expect(summary.service_income).to eq(100)
      expect(summary.care_products_income).to eq(100)
      expect(summary.total_income).to eq(200)
    end
  end

  describe "combined filters" do
    let(:service) { create(:service, user: user, service_type: "service", category: "coloring", subtype: "Balayage", price: 100) }
    let(:color_product) { create(:formula_product, user: user, category: "color") }
    let(:care_product) { create(:care_product, user: user) }

    let(:filters) do
      { service_ids: [ service.id ], formula_product_ids: [ color_product.id ], care_product_ids: [ care_product.id ] }
    end

    before do
      matching_appointment = create_appointment(service: service, time: "10:00")

      matching_note =
        create_note(appointment: matching_appointment, service: service,
          care_products: [
            { "care_product_id" => care_product.id, "name" => care_product.display_name, "price" => 50, "purchase_price" => 30, "qty" => 1 }
          ]
        )

      matching_step = create(:formula_step, service_note: matching_note)

      create(:formula_ingredient, formula_step: matching_step, formula_product: color_product, amount: 10, price: 5)

      sync_formula_charges(matching_note)

      other_appointment = create_appointment(service: service, time: "11:00")
      other_note = create_note(appointment: other_appointment, service: service)
      other_step = create(:formula_step, service_note: other_note)

      create(:formula_ingredient, formula_step: other_step, formula_product: color_product, amount: 10, price: 5)

      sync_formula_charges(other_note)
    end

    it "uses AND between different filter groups" do
      expect(summary.service_income).to eq(100)
      expect(summary.formula_income).to eq(50)
      expect(summary.care_products_income).to eq(50)
      expect(summary.total_income).to eq(200)
    end
  end

  describe "historical filter options" do
    let(:service) { create(:service, user: user, service_type: "service", category: "coloring", subtype: "Balayage", price: 100) }
    let(:color_product) { create(:formula_product, user: user, category: "color", brand: "Londa", name: "7/1") }
    let(:additive_product) { create(:formula_product, user: user, category: "additive", brand: "Wella", name: "Booster", unit: "ml") }
    let(:oxidant_product) { create(:formula_product, :oxidant, user: user, brand: "Inebrya", name: "6%") }
    let(:care_product) { create(:care_product, user: user) }

    before do
      appointment = create_appointment(service: service, time: "10:00")

      note =
        create_note(appointment: appointment, service: service,
          care_products: [
            { "care_product_id" => care_product.id, "name" => "Londa Repair Mask", "price" => 300, "purchase_price" => 180, "qty" => 1 }
          ]
        )

      step =
        create(:formula_step, service_note: note,
          oxidant: [
            { "formula_product_id" => oxidant_product.id, "amount" => 20, "price" => 2 }
          ]
        )

      create(:formula_ingredient, formula_step: step, formula_product: color_product, brand: "Londa", shade: "7/1", amount: 10, price: 5)
      create(:formula_ingredient, formula_step: step, formula_product: additive_product,
        kind: "additive", brand: "Wella", shade: "Booster", amount: 4, price: 3)

      sync_formula_charges(note)
    end

    it "builds color options from historical ingredient snapshots" do
      expect(summary.formula_color_options).to contain_exactly({ id: color_product.id, brand: "Londa", label: "Londa 7/1" })
    end

    it "builds additive options from historical charges" do
      expect(summary.additive_options).to contain_exactly({ id: additive_product.id, brand: "Wella", label: "Wella Booster" })
    end

    it "builds oxidant options from historical charges" do
      expect(summary.oxidant_options).to contain_exactly({ id: oxidant_product.id, brand: "Inebrya", label: "Inebrya 6%" })
    end

    it "builds care product options from sales" do
      expect(summary.care_product_options).to contain_exactly(
        { id: care_product.id, brand: care_product.brand, category: care_product.category, label: care_product.display_name }
      )
    end

    it "builds brands from historical formula options" do
      expect(summary.formula_color_brands).to eq([ "Londa" ])
      expect(summary.additive_brands).to eq([ "Wella" ])
      expect(summary.oxidant_brands).to eq([ "Inebrya" ])
    end

    it "builds care product brands and categories" do
      expect(summary.care_product_brands).to eq([ care_product.brand ])
      expect(summary.care_product_categories).to eq([ care_product.category ])
    end
  end

  describe "direct care product sales" do
    let(:care_product) { create(:care_product, user: user, purchase_price: 30, sale_price: 50, stock_quantity: 10) }

    it "includes direct sales in care product income" do
      create(:care_product_sale, user: user, care_product: care_product, quantity: 2, unit_price: 50, unit_cost: 30, sold_on: Date.current)

      expect(summary.care_products_income).to eq(100)
    end

    it "includes direct sales in care product income breakdown" do
      create(:care_product_sale, user: user, care_product: care_product, quantity: 2, unit_price: 50, unit_cost: 30, sold_on: Date.current)

      expect(summary.care_product_income).to contain_exactly(
        { id: care_product.id, label: care_product.display_name, amount: 100 }
      )
    end

    it "excludes direct sales when filtering by service" do
      service = create(:service, user: user, service_type: "service", category: "haircut", subtype: "Haircut", price: 100)

      create(:care_product_sale, user: user, care_product: care_product, quantity: 2, unit_price: 50, unit_cost: 30, sold_on: Date.current)

      filtered_summary = described_class.new(user: user, from: 1.month.ago.to_date, to: Date.current, service_ids: [ service.id ])

      expect(filtered_summary.care_products_income).to eq(0)
    end
  end

  describe "income breakdown" do
    let(:service) { create(:service, user: user, service_type: "service", category: "coloring", subtype: "Balayage", price: 100) }
    let(:color_product) { create(:formula_product, user: user, category: "color", brand: "Londa") }
    let(:oxidant_product) { create(:formula_product, user: user, category: "oxidant", brand: "Inebrya", name: "9%") }
    let(:care_product) { create(:care_product, user: user) }

    before do
      appointment = create_appointment(service: service, time: "10:00")

      note =
        create_note(appointment: appointment, service: service,
          care_products: [
            { "care_product_id" => care_product.id, "name" => "Londa Repair Mask", "price" => 300, "purchase_price" => 180, "qty" => 2 }
          ]
        )

      step =
        create(:formula_step, service_note: note, oxidant: [ { "formula_product_id" => oxidant_product.id, "amount" => 20, "price" => 2 } ])

      create(:formula_ingredient, formula_step: step, formula_product: color_product, brand: "Londa", shade: "7/1", amount: 10, price: 5)

      sync_formula_charges(note)
    end

    it "builds historical color income" do
      expect(summary.formula_color_income).to contain_exactly({ id: color_product.id, label: "Londa 7/1", amount: 50 })
    end

    it "builds historical oxidant income" do
      expect(summary.oxidant_income).to contain_exactly({ id: oxidant_product.id, label: "Inebrya 9%", amount: 40 })
    end

    it "builds care product income from historical sale prices" do
      expect(summary.care_product_income).to contain_exactly({ id: care_product.id, label: care_product.display_name, amount: 600 })
    end

    it "matches the formula breakdown with formula income" do
      breakdown_total =
        summary.formula_color_income.sum { |item| item[:amount] } +
        summary.additive_income.sum { |item| item[:amount] } +
        summary.oxidant_income.sum { |item| item[:amount] }

      expect(breakdown_total).to eq(summary.formula_income)
    end

    it "matches the care product breakdown with care products income" do
      breakdown_total = summary.care_product_income.sum { |item| item[:amount] }

      expect(breakdown_total).to eq(summary.care_products_income)
    end
  end

  describe "available formula filter options" do
    it "includes all color brands belonging to the user" do
      create(:formula_product, user: user, category: "color", brand: "Londa", name: "7/1")
      create(:formula_product, user: user, category: "color", brand: "Wella", name: "8/0")

      other_user = create(:user)

      create(:formula_product, user: other_user, category: "color", brand: "Matrix", name: "6/0")

      expect(summary.available_formula_color_brands).to eq([ "Londa", "Wella" ])
    end

    it "includes colors not used during the selected period" do
      product = create(:formula_product, user: user, category: "color", brand: "Londa", name: "7/1")

      expect(summary.available_formula_colors).to include({ id: product.id, brand: "Londa", label: "Londa 7/1" })
    end

    it "includes available additives" do
      product = create(:formula_product, user: user, category: "additive", brand: "Wella", name: "Booster")

      expect(summary.available_additives).to include({ id: product.id, brand: "Wella", label: "Wella Booster" })
      expect(summary.available_additive_brands).to eq([ "Wella" ])
    end

    it "includes all oxidant brands belonging to the user" do
      create(:formula_product, user: user, category: "oxidant", brand: "Inebrya", name: "3%")
      create(:formula_product, user: user, category: "oxidant", brand: "Nouvelle", name: "6%")

      expect(summary.available_oxidant_brands).to eq([ "Inebrya", "Nouvelle" ])
    end

    it "includes oxidants not used during the selected period" do
      product = create(:formula_product, user: user, category: "oxidant", brand: "Inebrya", name: "9%")

      expect(summary.available_oxidants).to include({ id: product.id, brand: "Inebrya", label: "Inebrya 9%" })
    end
  end

  describe "available care product filter options" do
    it "includes care products not sold during the period" do
      product = create(:care_product, user: user, brand: "Londa", name: "Repair Mask", category: "Mask")

      expect(summary.available_care_products).to include({ id: product.id, brand: "Londa", category: "Mask", label: product.display_name })
    end

    it "includes all care product brands" do
      create(:care_product, user: user, brand: "Lakme", name: "Repair Mask", category: "Mask")
      create(:care_product, user: user, brand: "Londa", name: "Deep Moisture", category: "Shampoo")

      expect(summary.available_care_product_brands).to eq([ "Lakme", "Londa" ])
    end

    it "includes all care product categories" do
      create(:care_product, user: user, brand: "Lakme", name: "Repair Mask", category: "Mask")
      create(:care_product, user: user, brand: "Londa", name: "Deep Moisture", category: "Shampoo")

      expect(summary.available_care_product_categories).to eq([ "Mask", "Shampoo" ])
    end

    it "does not include another user's care product brands" do
      create(:care_product, user: user, brand: "Londa", name: "Repair Mask", category: "Mask")

      other_user = create(:user)

      create(:care_product, user: other_user, brand: "Matrix", name: "Total Results", category: "Shampoo")

      expect(summary.available_care_product_brands).to eq([ "Londa" ])
    end
  end

  describe "additive income regression" do
    let(:service) { create(:service, user: user, service_type: "service", category: "coloring", subtype: "Balayage", price: 100) }

    let(:additive_product) do
      create(:formula_product, user: user, category: "additive", brand: "Wella", name: "Booster", unit: "ml", price_per_unit: 3)
    end

    it "counts additives separately and supports filtering by additive product" do
      appointment = create_appointment(service: service, time: "10:00")
      note = create_note(appointment: appointment, service: service)
      step = create(:formula_step, service_note: note)

      create(:formula_ingredient, formula_step: step, formula_product: additive_product, kind: "additive",
        brand: "Wella", shade: "Booster", amount: 4, price: 3)

      sync_formula_charges(note)

      expect(summary.additive_income).to contain_exactly(id: additive_product.id, label: "Wella Booster", amount: 12)
      expect(summary.formula_color_income).to be_empty
      expect(summary.formula_income).to eq(12)
      expect(summary.total_income).to eq(112)

      filtered = described_class.new(user: user, from: 1.month.ago.to_date, to: Date.current, formula_product_ids: [ additive_product.id ])

      expect(filtered.formula_income).to eq(12)
      expect(filtered.service_income).to eq(100)
      expect(filtered.additive_income.sum { |row| row[:amount] }).to eq(12)
    end

    it "does not include other users' additive charges" do
      other_user = create(:user)
      other_client = create(:client, user: other_user)
      other_appointment = create(:appointment, user: other_user, client: other_client)
      other_note = create(:service_note, user: other_user, client: other_client, appointment: other_appointment)
      step = create(:formula_step, service_note: other_note)
      product = create(:formula_product, user: other_user, category: "additive", name: "Private")

      create(:formula_ingredient, formula_step: step, formula_product: product, kind: "additive", shade: "Private", amount: 3, price: 5)

      sync_formula_charges(other_note)

      expect(summary.additive_income).to be_empty
      expect(summary.formula_income).to eq(0)
    end
  end

  describe "filter normalization" do
    let(:filters) do
      {
        service_categories: [ "coloring", "", "coloring", nil ],
        service_ids: [ "1", "1", "invalid", nil ],
        formula_product_ids: [ "2", "invalid", "2" ],
        care_product_ids: [ "3", "", "3" ]
      }
    end

    it "removes blank, invalid and duplicate filter values" do
      expect(summary.service_categories).to eq([ "coloring" ])
      expect(summary.service_ids).to eq([ 1 ])
      expect(summary.formula_product_ids).to eq([ 2 ])
      expect(summary.care_product_ids).to eq([ 3 ])
    end
  end

  describe "empty results" do
    it "returns zero income when there are no records" do
      expect(summary.grouped_service_income).to eq({})
      expect(summary.service_income).to eq(0)
      expect(summary.formula_income).to eq(0)
      expect(summary.care_products_income).to eq(0)
      expect(summary.total_income).to eq(0)
    end

    it "returns empty income breakdowns" do
      expect(summary.formula_color_income).to eq([])
      expect(summary.additive_income).to eq([])
      expect(summary.oxidant_income).to eq([])
      expect(summary.care_product_income).to eq([])
    end

    it "returns empty historical filter options" do
      expect(summary.formula_color_options).to eq([])
      expect(summary.additive_options).to eq([])
      expect(summary.oxidant_options).to eq([])
      expect(summary.care_product_options).to eq([])
    end
  end
end

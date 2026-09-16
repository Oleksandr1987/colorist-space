require "rails_helper"

RSpec.describe Analytics::IncomeSummary do
  subject(:summary) do
    described_class.new(user: user, from: 1.month.ago.to_date, to: Date.current, **filters)
  end

  let(:user) { create(:user) }
  let(:client) { create(:client, user: user) }
  let(:filters) { {} }

  def create_appointment(service:, time:)
    create(:appointment,
      user: user,
      client: client,
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
        create_appointment(service: other_service, time: "11:00")
      end

      it "includes only appointments containing the selected color" do
        expect(summary.service_income).to eq(100)
        expect(summary.formula_income).to eq(50)
        expect(summary.total_income).to eq(150)
      end
    end

    context "when an oxidant is selected" do
      let(:oxidant_product) { create(:formula_product, user: user, category: "oxidant") }
      let(:filters) { { formula_product_ids: [ oxidant_product.id ] } }

      before do
        appointment = create_appointment(service: service, time: "10:00")
        note = create_note(appointment: appointment, service: service)

        create(:formula_step,
          service_note: note,
          oxidant: [
            { "formula_product_id" => oxidant_product.id, "amount" => 20, "price" => 2 }
          ]
        )

        create_appointment(service: other_service, time: "11:00")
      end

      it "includes only appointments containing the selected oxidant" do
        expect(summary.service_income).to eq(100)
        expect(summary.formula_income).to eq(40)
        expect(summary.total_income).to eq(140)
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

      create_note(
        appointment: appointment,
        service: service,
        care_products: [
          {
            "care_product_id" => care_product.id,
            "name" => care_product.display_name,
            "price" => 50,
            "purchase_price" => 30,
            "qty" => 2
          }
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
        create_note(
          appointment: matching_appointment,
          service: service,
          care_products: [
            {
              "care_product_id" => care_product.id,
              "name" => care_product.display_name,
              "price" => 50,
              "purchase_price" => 30,
              "qty" => 1
            }
          ]
        )

      matching_step = create(:formula_step, service_note: matching_note)

      create(:formula_ingredient,
        formula_step: matching_step,
        formula_product: color_product,
        amount: 10,
        price: 5
      )

      other_appointment = create_appointment(service: service, time: "11:00")
      other_note = create_note(appointment: other_appointment, service: service)
      other_step = create(:formula_step, service_note: other_note)

      create(:formula_ingredient,
        formula_step: other_step,
        formula_product: color_product,
        amount: 10,
        price: 5
      )
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
    let(:color_product) { create(:formula_product, user: user, category: "color") }
    let(:care_product) { create(:care_product, user: user) }

    before do
      appointment = create_appointment(service: service, time: "10:00")

      note =
        create_note(
          appointment: appointment,
          service: service,
          care_products: [
            {
              "care_product_id" => care_product.id,
              "name" => "Londa Visible Repair Mask",
              "price" => 300,
              "purchase_price" => 180,
              "qty" => 1
            }
          ]
        )

      step = create(:formula_step, service_note: note)

      create(:formula_ingredient,
        formula_step: step,
        formula_product: color_product,
        brand: "Londa",
        shade: "7/1",
        amount: 10,
        price: 5
      )
    end

    it "builds color options from historical ingredient snapshots" do
      expect(summary.formula_color_options).to contain_exactly(
        { id: color_product.id, brand: "Londa", label: "Londa 7/1" }
      )
    end

    it "builds care product options from historical snapshots" do
      expect(summary.care_product_options).to contain_exactly(
        { id: care_product.id, brand: care_product.brand, category: care_product.category, label: "Londa Visible Repair Mask" }
      )
    end

    it "builds color brands from historical color options" do
      expect(summary.formula_color_brands).to eq([ "Londa" ])
    end

    it "builds care product brands from historical care product options" do
      expect(summary.care_product_brands).to eq([ care_product.brand ])
    end

    it "builds care product categories from historical care product options" do
      expect(summary.care_product_categories).to eq([ care_product.category ])
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
        create_note(
          appointment: appointment,
          service: service,
          care_products: [
            {
              "care_product_id" => care_product.id,
              "name" => "Londa Visible Repair Mask",
              "price" => 300,
              "purchase_price" => 180,
              "qty" => 2
            }
          ]
        )

      step =
        create(:formula_step, service_note: note,
          oxidant: [ { "formula_product_id" => oxidant_product.id, "amount" => 20, "price" => 2 } ]
        )

      create(:formula_ingredient,
        formula_step: step,
        formula_product: color_product,
        brand: "Londa",
        shade: "7/1",
        amount: 10,
        price: 5
      )
    end

    it "builds historical color income" do
      expect(summary.formula_color_income).to contain_exactly(
        { id: color_product.id, label: "Londa 7/1", amount: 50 }
      )
    end

    it "builds historical oxidant income" do
      expect(summary.oxidant_income).to contain_exactly(
        { id: oxidant_product.id, label: "Inebrya 9%", amount: 40 }
      )
    end

    it "builds historical care product income" do
      expect(summary.care_product_income).to contain_exactly(
        { id: care_product.id, label: "Londa Visible Repair Mask", amount: 600 }
      )
    end

    it "matches the formula breakdown with formula income" do
      breakdown_total =
        summary.formula_color_income.sum { |item| item[:amount] } +
        summary.oxidant_income.sum { |item| item[:amount] }

      expect(breakdown_total).to eq(summary.formula_income)
    end

    it "matches the care product breakdown with care products income" do
      breakdown_total = summary.care_product_income.sum { |item| item[:amount] }

      expect(breakdown_total).to eq(summary.care_products_income)
    end
  end

  describe "#available_formula_color_brands" do
    it "includes all user brands even when they were not used during the period" do
      create(:formula_product, user: user, category: "color", brand: "Londa", name: "7/1")
      create(:formula_product, user: user, category: "color", brand: "Wella", name: "8/0")

      other_user = create(:user)

      create(:formula_product, user: other_user, category: "color", brand: "Matrix", name: "6/0")

      expect(summary.available_formula_color_brands).to eq([ "Londa", "Wella" ])
    end
  end

  describe "#available_formula_colors" do
    it "includes colors that were not used during the period" do
      product = create(:formula_product, user: user, category: "color", brand: "Londa", name: "7/1")

      expect(summary.available_formula_colors).to include(
        { id: product.id, brand: "Londa", label: "Londa 7/1" }
      )
    end
  end

  describe "#available_oxidant_brands" do
    it "includes all user brands even when they were not used during the period" do
      create(:formula_product, user: user, category: "oxidant", brand: "Inebrya", name: "3%")
      create(:formula_product, user: user, category: "oxidant", brand: "Nouvelle", name: "6%")

      expect(summary.available_oxidant_brands).to eq([ "Inebrya", "Nouvelle" ])
    end
  end

  describe "#available_oxidants" do
    it "includes oxidants that were not used during the period" do
      product = create(:formula_product, user: user, category: "oxidant", brand: "Inebrya", name: "9%")

      expect(summary.available_oxidants).to include({ id: product.id, brand: "Inebrya", label: "Inebrya 9%" })
    end
  end

  describe "available care product filter options" do
    describe "#available_care_products" do
      it "includes care products even when they were not sold during the period" do
        product = create(:care_product, user: user, brand: "Londa", name: "Repair Mask", category: "Mask")

        expect(summary.available_care_products).to include(
          { id: product.id, brand: "Londa", category: "Mask", label: product.display_name }
        )
      end
    end

    describe "#available_care_product_brands" do
      it "includes brands even when they were not sold during the period" do
        create(:care_product, user: user, brand: "Lakme", name: "Repair Mask", category: "Mask")
        create(:care_product, user: user, brand: "Londa", name: "Deep Moisture", category: "Shampoo")

        expect(summary.available_care_product_brands).to eq([ "Lakme", "Londa" ])
      end
    end

    describe "#available_care_product_categories" do
      it "includes categories even when products were not sold during the period" do
        create(:care_product, user: user, brand: "Lakme", name: "Repair Mask", category: "Mask")
        create(:care_product, user: user, brand: "Londa", name: "Deep Moisture", category: "Shampoo")

        expect(summary.available_care_product_categories).to eq([ "Mask", "Shampoo" ])
      end
    end

    describe "user isolation" do
      it "does not include care products belonging to another user" do
        create(:care_product, user: user, brand: "Londa", name: "Repair Mask", category: "Mask")

        other_user = create(:user)

        create(:care_product, user: other_user, brand: "Matrix", name: "Total Results", category: "Shampoo")

        expect(summary.available_care_product_brands).to eq([ "Londa" ])
      end
    end
  end
end

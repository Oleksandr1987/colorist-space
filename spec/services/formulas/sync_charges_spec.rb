require "rails_helper"

RSpec.describe Formulas::SyncCharges do
  subject(:sync_charges) { described_class.new(service_note: service_note) }

  let(:user) { create(:user) }
  let(:client) { create(:client, user: user) }
  let(:service) { create(:service, user: user, category: "coloring", subtype: "Color", price: 200) }
  let(:appointment) { create(:appointment, user: user, client: client, main_service: service) }
  let(:service_note) { create(:service_note, user: user, client: client, appointment: appointment) }
  let(:color_product) { create(:formula_product, user: user, category: "color", brand: "Wella", name: "Koleston 7/1", unit: "g") }
  let(:oxidant_product) { create(:formula_product, :oxidant, user: user, brand: "Wella", name: "6%", unit: "ml") }

  describe "#call" do
    it "creates a historical charge for a color ingredient" do
      step = create(:formula_step, service_note: service_note)

      create(:formula_ingredient, formula_step: step, formula_product: color_product, brand: "Wella", shade: "7/1", amount: 10, price: 5)

      expect { sync_charges.call }.to change(FormulaCharge, :count).by(1)

      charge = service_note.formula_charges.first

      expect(charge).to have_attributes(
        user: user,
        appointment: appointment,
        formula_product: color_product,
        kind: "color",
        brand: "Wella",
        product_name: "7/1",
        amount: 10,
        unit: "g",
        unit_price: 5,
        total: 50
      )
    end

    it "creates a historical charge for an oxidant" do
      create(:formula_step, service_note: service_note,
        oxidant: [ { "formula_product_id" => oxidant_product.id, "amount" => 20, "price" => 2 } ]
      )

      expect { sync_charges.call }.to change(FormulaCharge, :count).by(1)

      charge = service_note.formula_charges.first

      expect(charge).to have_attributes(
        user: user,
        appointment: appointment,
        formula_product: oxidant_product,
        kind: "oxidant",
        brand: "Wella",
        product_name: "6%",
        amount: 20,
        unit: "ml",
        unit_price: 2,
        total: 40
      )
    end

    it "creates color and oxidant charges together" do
      step =
        create(:formula_step, service_note: service_note,
          oxidant: [ { "formula_product_id" => oxidant_product.id, "amount" => 20, "price" => 2 } ]
        )

      create(:formula_ingredient, formula_step: step, formula_product: color_product, amount: 10, price: 5)

      expect { sync_charges.call }.to change(FormulaCharge, :count).by(2)
      expect(service_note.formula_charges.pluck(:kind)).to contain_exactly("color", "oxidant")
      expect(service_note.formula_charges.sum(:total)).to eq(90)
    end

    it "replaces existing charges when the formula changes" do
      step = create(:formula_step, service_note: service_note)
      ingredient = create(:formula_ingredient, formula_step: step, formula_product: color_product, amount: 10, price: 5)

      sync_charges.call

      expect(service_note.formula_charges.count).to eq(1)
      expect(service_note.formula_charges.sum(:total)).to eq(50)

      ingredient.update!(amount: 20)

      expect { described_class.new(service_note: service_note.reload).call }.not_to change(FormulaCharge, :count)
      expect(service_note.formula_charges.reload.sum(:total)).to eq(100)
    end

    it "removes charges for formula items that were removed" do
      step = create(:formula_step, service_note: service_note)
      ingredient = create(:formula_ingredient, formula_step: step, formula_product: color_product, amount: 10, price: 5)

      sync_charges.call

      expect(service_note.formula_charges.count).to eq(1)

      ingredient.destroy!

      described_class.new(service_note: service_note.reload).call

      expect(service_note.formula_charges.reload).to be_empty
    end

    it "does not duplicate charges when synchronized repeatedly" do
      step = create(:formula_step, service_note: service_note)

      create(:formula_ingredient, formula_step: step, formula_product: color_product, amount: 10, price: 5)

      sync_charges.call

      expect { described_class.new(service_note: service_note.reload).call }.not_to change(FormulaCharge, :count)
    end
  end
end

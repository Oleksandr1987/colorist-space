#!/usr/bin/env python3
"""Append regression examples to existing RSpec files. Creates no spec files."""
from pathlib import Path
import sys
root = Path(sys.argv[1] if len(sys.argv) > 1 else '.')
specs = root / 'spec'
if not specs.is_dir():
    raise SystemExit('spec/ not found: run this from Rails project root')
blocks = {
 'RSpec.describe Formulas::SyncCharges do': '''
  describe "additive regression" do
    let(:additive_product) { create(:formula_product, user: user, category: "additive", brand: "Wella", name: "Booster", unit: "ml", price_per_unit: 3) }

    it "saves color and additive as distinct historical charge kinds and units" do
      step = create(:formula_step, service_note: service_note)
      create(:formula_ingredient, formula_step: step, formula_product: color_product, kind: "color", shade: "7/1", amount: 10, price: 5)
      create(:formula_ingredient, formula_step: step, formula_product: additive_product, kind: "additive", brand: "Wella", shade: "Booster", amount: 4, price: 3)

      sync_charges.call

      expect(service_note.formula_charges.pluck(:kind)).to contain_exactly("color", "additive")
      additive = service_note.formula_charges.find_by!(kind: "additive")
      expect(additive).to have_attributes(formula_product: additive_product, amount: 4, unit: "ml", unit_price: 3, total: 12)
      expect(service_note.formula_charges.sum(:total)).to eq(62)
    end

    it "does not charge an ingredient marked for destruction" do
      step = create(:formula_step, service_note: service_note)
      ingredient = create(:formula_ingredient, formula_step: step, formula_product: additive_product, kind: "additive", shade: "Booster", amount: 4, price: 3)
      step.formula_ingredients.load
      step.formula_ingredients.first.mark_for_destruction

      expect { sync_charges.call }.not_to change(FormulaCharge, :count)
    end

    it "uses g when an additive has no linked catalog product" do
      step = create(:formula_step, service_note: service_note)
      create(:formula_ingredient, formula_step: step, formula_product: nil, kind: "additive", brand: "Archived", shade: "Booster", amount: 2, price: 4)

      sync_charges.call

      expect(service_note.formula_charges.first).to have_attributes(kind: "additive", unit: "g", total: 8)
    end
  end
''',
 'RSpec.describe ServiceNote do': '''
  describe "additive price regression" do
    it "includes additives exactly once in the formula total and final price" do
      step = create(:formula_step, service_note: note, oxidant: [{ "formula_product_id" => 1, "amount" => 10, "price" => 2 }])
      create(:formula_ingredient, formula_step: step, kind: "color", amount: 5, price: 3)
      create(:formula_ingredient, formula_step: step, kind: "additive", shade: "Booster", amount: 4, price: 7)

      expect(note.reload.additives_total_price).to eq(28)
      expect(note.formula_ingredients_total_price).to eq(63)
      expect(note.final_price).to eq(note.services_total + 63 + note.care_products_income)
    end
  end
''',
 'RSpec.describe FormulaProduct do': '''
  describe "additive regression" do
    it "allows additive category and requires a name" do
      product = build(:formula_product, category: "additive", name: "")
      expect(product).not_to be_valid
      expect(product.errors[:name]).to be_present
      product.name = "Booster"
      expect(product).to be_valid
    end

    it "keeps additives separate from colors and oxidants" do
      additive = create(:formula_product, category: "additive", name: "Booster")
      expect(described_class.additives).to include(additive)
      expect(described_class.colors).not_to include(additive)
      expect(described_class.oxidants).not_to include(additive)
    end
  end
''',
 'RSpec.describe Analytics::IncomeSummary do': '''
  describe "additive income regression" do
    let(:service) { create(:service, user: user, service_type: "service", category: "coloring", subtype: "Balayage", price: 100) }
    let(:additive_product) { create(:formula_product, user: user, category: "additive", brand: "Wella", name: "Booster", unit: "ml", price_per_unit: 3) }

    it "counts additives separately and supports filtering by additive product" do
      appointment = create_appointment(service: service, time: "10:00")
      note = create_note(appointment: appointment, service: service)
      step = create(:formula_step, service_note: note)
      create(:formula_ingredient, formula_step: step, formula_product: additive_product, kind: "additive", brand: "Wella", shade: "Booster", amount: 4, price: 3)
      sync_formula_charges(note)

      expect(summary.additive_income).to contain_exactly(id: additive_product.id, label: "Wella Booster", amount: 12)
      expect(summary.formula_color_income).to be_empty
      expect(summary.formula_income).to eq(12)
      expect(summary.total_income).to eq(112)

      filtered = described_class.new(user: user, from: 1.month.ago.to_date, to: Date.current, formula_product_ids: [additive_product.id])
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
''',
 'RSpec.describe "FormulaProducts" do': '''
  describe "additive product requests" do
    it "creates an additive and redirects to the additive tab" do
      expect {
        post formula_products_path, params: { formula_product: { category: "additive", brand: "Wella", name: "Booster", unit: "ml", price_per_unit: 3 } }
      }.to change(FormulaProduct, :count).by(1)

      expect(FormulaProduct.last).to have_attributes(user: user, category: "additive", name: "Booster")
      expect(response).to redirect_to(formula_products_path(category: "additive", locale: I18n.locale))
    end

    it "rejects an additive without a name" do
      expect {
        post formula_products_path, params: { formula_product: { category: "additive", brand: "Wella", name: "", unit: "ml", price_per_unit: 3 } }
      }.not_to change(FormulaProduct, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
''',
}
for marker, block in blocks.items():
    matches = [p for p in specs.rglob('*.rb') if marker in p.read_text()]
    if len(matches) != 1:
        raise SystemExit(f'Expected one existing spec for {marker}, found {len(matches)}: {matches}')
    path = matches[0]
    original = path.read_text()
    if 'additive regression' in original or 'additive income regression' in original or 'additive product requests' in original or 'additive price regression' in original:
        print(f'Already updated: {path}')
        continue
    pos = original.rfind('\nend')
    if pos < 0:
        raise SystemExit(f'Cannot find closing end in {path}')
    path.write_text(original[:pos] + '\n' + block + original[pos:])
    print(f'Updated: {path}')
print('All changes applied to existing spec files only.')

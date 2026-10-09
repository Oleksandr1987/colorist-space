require "rails_helper"

RSpec.describe ServiceNote do
  let(:user) { create(:user) }
  let(:client) { create(:client, user: user) }
  let(:appointment) { create(:appointment, user: user, client: client) }
  let(:service) { create(:service, user: user, subtype: "Color", price: 100) }
  let(:extra_service) { create(:service, user: user, subtype: "Cut", price: 200) }
  let(:note) { create(:service_note, appointment: appointment, user: user, client: client) }
  let(:step_one) { instance_double(FormulaStep, oxidant_amount: 10, oxidant_total_price: 50) }
  let(:step_two) { instance_double(FormulaStep, oxidant_amount: 15, oxidant_total_price: 75) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:client) }
    it { is_expected.to belong_to(:appointment) }
    it { is_expected.to have_many(:formula_steps).dependent(:destroy) }
    it { is_expected.to have_many(:formula_charges).dependent(:nullify) }
    it { is_expected.to have_many(:care_product_sales).dependent(:nullify) }
    it { is_expected.to have_many(:care_product_stock_movements).dependent(:nullify) }
  end

  describe "scope .for_client" do
    let(:client) { create(:client) }
    let(:user) { client.user }
    let!(:older) { create(:service_note, client: client, user: user, created_at: 2.days.ago) }
    let!(:newer) { create(:service_note, client: client, user: user, created_at: 1.day.ago) }

    it "returns notes ordered by created_at desc" do
      expect(described_class.for_client(client.id)).to eq([ newer, older ])
    end
  end

  describe "validations" do
    it "validates uniqueness of appointment_id" do
      create(:service_note, appointment: appointment)

      duplicate = build(:service_note, appointment: appointment)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:appointment_id]).to be_present
    end

    it "is valid without services" do
      appointment = create(:appointment, user: user, client: client, main_service: nil)
      service_note = build(:service_note, :without_services, appointment: appointment, user: user, client: client)

      expect(service_note).to be_valid
    end
  end

  describe "before_validation set_price_from_services" do
    it "sets price from services if present" do
      note.price = nil
      note.services = [ service, extra_service ]

      note.valid?

      expect(note.price).to eq(300)
    end

    it "does not override existing price" do
      note.price = 500
      note.services = [ service ]

      note.valid?

      expect(note.price).to eq(500)
    end

    it "keeps price nil if no services" do
      service_note = build(:service_note, :without_services, price: nil)

      service_note.valid?

      expect(service_note.price).to be_nil
    end
  end

  describe "callbacks: notes sync" do
    let(:appointment) { create(:appointment, notes: "Appointment note") }

    context "when copy_notes_from_appointment" do
      it "copies notes from appointment on create if notes blank" do
        note = build(:service_note, appointment: appointment, notes: nil)

        note.valid?

        expect(note.notes).to eq("Appointment note")
      end

      it "does not override existing notes" do
        note = build(:service_note, appointment: appointment, notes: "Own note")

        note.valid?

        expect(note.notes).to eq("Own note")
      end

      it "does nothing if appointment has no notes" do
        appointment.update!(notes: nil)

        note = build(:service_note, appointment: appointment, notes: nil)

        note.valid?

        expect(note.notes).to be_nil
      end
    end

    context "when sync_appointment_notes" do
      it "updates appointment notes after save" do
        create(:service_note, appointment: appointment, notes: "New note")

        expect(appointment.reload.notes).to eq("New note")
      end

      it "does not update if notes are the same" do
        note = create(:service_note, appointment: appointment, notes: "Same note")

        appointment.update!(notes: "Same note")

        expect { note.save! }.not_to change { appointment.reload.notes }
      end
    end
  end

  describe "callbacks: services sync" do
    context "when sync_appointment_services" do
      it "syncs services to appointment after save" do
        note.services = [ service, extra_service ]

        note.save!

        expect(appointment.reload.services).to contain_exactly(service, extra_service)
      end

      it "updates service_name on appointment" do
        note.services = [ service, extra_service ]

        note.save!

        expect(appointment.reload.service_name).to eq("Color + Cut")
      end
    end
  end

  describe "#service_names" do
    it "joins service subtypes with +" do
      note.services = [ service, extra_service ]

      expect(note.service_names).to eq("Color + Cut")
    end
  end

  describe "#all_services" do
    let(:appointment) { create(:appointment,  user: user, client: client, main_service: nil) }

    it "returns own services when present" do
      note.services = [ service ]

      expect(note.all_services).to contain_exactly(service)
    end

    it "returns appointment services when own services absent" do
      appointment.sync_services_with_prices!([ service.id ])

      built_note = build(:service_note, appointment: appointment, user: appointment.user, client: appointment.client)
      built_note.services = []

      expect(built_note.services).to be_empty
      expect(built_note.all_services).to contain_exactly(service)
    end

    it "returns appointment services when note has no services and appointment has services" do
      appointment.sync_services_with_prices!([ service.id ])

      built_note = build(:service_note, appointment: appointment, user: appointment.user, client: appointment.client)
      built_note.services = []

      expect(built_note.services).to be_empty
      expect(built_note.appointment.services).to contain_exactly(service)
      expect(built_note.all_services).to contain_exactly(service)
    end

    it "returns empty relation when appointment is nil" do
      user = create(:user)
      client = create(:client, user: user)
      built_note = build(:service_note, :without_services, appointment: nil, user: user, client: client)

      expect(built_note.all_services).to be_empty
    end
  end

  describe "#developer_total_amount" do
    it "returns sum of oxidant amounts" do
      allow(note).to receive(:formula_steps).and_return([ step_one, step_two ])

      expect(note.developer_total_amount).to eq(25)
    end

    it "returns 0 when no formula steps" do
      expect(note.developer_total_amount).to eq(0)
    end
  end

  describe "#developer_total_price" do
    it "returns sum of oxidant total prices" do
      allow(note).to receive(:formula_steps).and_return([ step_one, step_two ])

      expect(note.developer_total_price).to eq(125)
    end

    it "returns 0 when no formula steps" do
      expect(note.developer_total_price).to eq(0)
    end
  end

  describe "#care_products_total" do
    it "returns total from care products" do
      note = create(:service_note, care_products: [ { "price" => 100, "qty" => 2 }, { "price" => 50, "qty" => 3 } ])

      expect(note.care_products_total).to eq(350)
    end

    it "returns 0 when care_products is not array" do
      note = create(:service_note, care_products: nil)

      expect(note.care_products_total).to eq(0)
    end

    it "returns 0 for empty array" do
      note = create(:service_note, care_products: [])

      expect(note.care_products_total).to eq(0)
    end
  end

  describe "#final_price" do
    let(:price_note) do
      create(:service_note, :without_services, appointment: appointment, user: user, client: client)
    end

    it "returns services + formula + care products income" do
      price_note.services = [ service, extra_service ]
      price_note.save!

      allow(price_note).to receive_messages(formula_ingredients_total_price: 75, care_products_income: 100)

      expect(price_note.final_price).to eq(475)
    end

    it "returns only historical services total when others absent" do
      price_note.services = [ service ]
      price_note.save!

      allow(price_note).to receive_messages(formula_ingredients_total_price: 0, care_products_income: 0)

      expect(price_note.final_price).to eq(100)
    end

    it "uses historical service price after catalog price changes" do
      price_note.services = [ service ]
      price_note.save!

      service.update!(price: 500)

      allow(price_note).to receive_messages(formula_ingredients_total_price: 0, care_products_income: 0)

      expect(price_note.final_price).to eq(100)
    end
  end

  describe "#formula_ingredients_total_price" do
    it "sums colors and oxidant totals across all formula steps" do
      step = create(:formula_step, service_note: note,
        oxidant: [ { "formula_product_id" => 1, "amount" => 10, "price" => 2 } ]
      )

      create(:formula_ingredient, formula_step: step, amount: 5, price: 3)

      expect(note.reload.formula_ingredients_total_price).to eq(35)
    end

    it "returns 0 when there are no formula steps" do
      expect(note.formula_ingredients_total_price).to eq(0)
    end
  end

  describe "#care_products_income" do
    it "returns sale income from care products" do
      note.care_products = [
        { "price" => 100, "purchase_price" => 60, "qty" => 2 },
        { "price" => 50, "purchase_price" => 30, "qty" => 3 }
      ]

      expect(note.care_products_income).to eq(350)
    end

    it "returns 0 when care_products is not an array" do
      note.care_products = nil

      expect(note.care_products_income).to eq(0)
    end
  end

  describe "#care_products_cost" do
    it "returns historical purchase cost from care products" do
      note.care_products = [
        { "price" => 100, "purchase_price" => 60, "qty" => 2 },
        { "price" => 50, "purchase_price" => 30, "qty" => 3 }
      ]

      expect(note.care_products_cost).to eq(210)
    end

    it "returns 0 when care_products is not an array" do
      note.care_products = nil

      expect(note.care_products_cost).to eq(0)
    end
  end

  describe "#reject_empty_haircut_step?" do
    it "rejects nested haircut step attributes that are entirely blank" do
      note.haircut_steps_attributes = [
        { zone: "", instrument: "", parting: "", elevation: "", cut_type: "", notes: "" }
      ]

      expect(note.haircut_steps).to be_empty
    end

    it "keeps nested haircut step attributes when any value is present" do
      note.haircut_steps_attributes = [ { zone: "crown" } ]

      expect(note.haircut_steps.size).to eq(1)
    end
  end

  describe "#appointment_date" do
    it "returns appointment appointment_date" do
      appointment = create(:appointment, appointment_date: Date.current + 3.days)

      note = create(:service_note, appointment: appointment)

      expect(note.appointment_date).to eq(appointment.appointment_date)
    end
  end

  describe "#decorated_photos" do
    it "decorates all photos" do
      file = fixture_file_upload(Rails.root.join("spec/fixtures/files/test_image.jpg"), "image/jpg")

      note.photos.attach(file)

      decorated = instance_double(PhotoDecorator)

      allow(PhotoDecorator).to receive(:decorate).and_return(decorated)

      expect(note.decorated_photos).to eq([ decorated ])
    end
  end

  describe "sync_appointment_services edge cases" do
    it "does nothing when appointment absent" do
      note = build(:service_note, appointment: nil)

      expect { note.send(:sync_appointment_services) }.not_to raise_error
    end

    it "preserves appointment services and historical prices when service note has no services" do
      appointment.sync_services_with_prices!([ service.id ])

      service_note =
        build(:service_note, :without_services, appointment: appointment, user: appointment.user, client: appointment.client)

      expect { service_note.save! }.not_to change {
        appointment.reload.appointment_services_relations.pluck(:service_id, :price)
      }

      expect(appointment.reload.services).to contain_exactly(service)
    end
  end

  describe "sync_appointment_notes edge cases" do
    it "does nothing when appointment absent" do
      note = build(:service_note, appointment: nil)

      expect { note.send(:sync_appointment_notes) }.not_to raise_error
    end
  end

  describe "care products stock management" do
    let(:care_product) { create(:care_product, stock_quantity: 10) }

    describe "#create_care_product_sales" do
      let(:care_product) { create(:care_product, user: user, purchase_price: 60, sale_price: 100, stock_quantity: 10) }
      let(:care_products) { [ { "care_product_id" => care_product.id, "price" => 100, "purchase_price" => 60, "qty" => 3 } ] }

      def create_note_with_care_products
        create(:service_note, user: user, client: client, appointment: appointment, care_products: care_products)
      end

      it "creates care product sale after create" do
        expect { create_note_with_care_products }.to change(user.care_product_sales, :count).by(1)
      end

      it "stores sale snapshots" do
        sale = create_note_with_care_products.care_product_sales.last

        expect(sale.quantity).to eq(3)
        expect(sale.unit_price).to eq(100)
        expect(sale.unit_cost).to eq(60)
        expect(sale.sold_on).to eq(appointment.appointment_date)
      end

      it "decreases stock through sale" do
        expect { create_note_with_care_products }.to change { care_product.reload.stock_quantity }.from(10).to(7)
      end

      it "creates sale stock movement" do
        expect { create_note_with_care_products }.to change(user.care_product_stock_movements, :count).by(1)

        movement = user.care_product_stock_movements.last

        expect(movement.movement_type).to eq("sale")
        expect(movement.quantity).to eq(-3)
        expect(movement.unit_cost).to eq(60)
      end

      it "links sale and movement to service note" do
        sale = create_note_with_care_products.care_product_sales.last

        expect(sale.service_note).to eq(note = sale.service_note)
        expect(sale.stock_movement.service_note).to eq(note)
      end
    end

    describe "care product sales synchronization" do
      let(:care_product) { create(:care_product, user: user, purchase_price: 60, sale_price: 100, stock_quantity: 10) }
      let(:care_products) { [ { "care_product_id" => care_product.id, "price" => 100, "purchase_price" => 60, "qty" => 2 } ] }
      let(:service_note) { create(:service_note, user: user, client: client, appointment: appointment, care_products: care_products) }

      it "synchronizes sale when care products change" do
        service_note

        expect do
          service_note.update!(
            care_products: [ { "care_product_id" => care_product.id, "price" => 100, "purchase_price" => 60, "qty" => 5 } ]
          )
        end.to change { service_note.care_product_sales.first.reload.quantity }.from(2).to(5)
      end

      it "synchronizes stock when care products change" do
        service_note

        expect do
          service_note.update!(
            care_products: [ { "care_product_id" => care_product.id, "price" => 100, "purchase_price" => 60, "qty" => 5 } ]
          )
        end.to change { care_product.reload.stock_quantity }.from(8).to(5)
      end

      it "does not synchronize sales when care products do not change" do
        allow(CareProducts::SyncServiceNoteSales).to receive(:new)
        service_note

        expect(CareProducts::SyncServiceNoteSales).not_to have_received(:new)

        service_note.update!(notes: "Updated note")
      end
    end

    describe "historical financial records on destroy" do
      let(:care_product) { create(:care_product, user: user, purchase_price: 60, sale_price: 100, stock_quantity: 10) }
      let(:care_products) { [ { "care_product_id" => care_product.id, "price" => 100, "purchase_price" => 60, "qty" => 3 } ] }
      let(:formula_product) { create(:formula_product, user: user, category: "color", brand: "Wella", name: "Koleston 7/1", unit: "g") }
      let(:historical_service) { create(:service, user: user, category: "coloring", subtype: "Color", price: 200) }
      let(:historical_appointment) { create(:appointment, user: user, client: client, main_service: historical_service) }
      let(:service_note) do
        create(:service_note, user: user, client: client, appointment: historical_appointment, care_products: care_products)
      end

      before do
        step = create(:formula_step, service_note: service_note)

        create(:formula_ingredient, formula_step: step, formula_product: formula_product, brand: "Wella", shade: "7/1", amount: 10, price: 5)

        Formulas::SyncCharges.new(service_note: service_note.reload).call
      end

      it "preserves historical financial records when service note is destroyed" do
        formula_charge_ids = service_note.formula_charges.ids
        sale_ids = service_note.care_product_sales.ids
        service_relation_ids = historical_appointment.appointment_services_relations.ids

        service_note.destroy!

        expect(FormulaCharge.where(id: formula_charge_ids).ids).to match_array(formula_charge_ids)
        expect(CareProductSale.where(id: sale_ids).ids).to match_array(sale_ids)
        expect(AppointmentServicesRelation.where(id: service_relation_ids).ids).to match_array(service_relation_ids)
      end

      it "does not restore care product stock when service note is destroyed" do
        expect(care_product.reload.stock_quantity).to eq(7)
        expect { service_note.destroy! }.not_to change { care_product.reload.stock_quantity }
      end

      it "does not create a cancellation stock movement when service note is destroyed" do
        service_note

        expect { service_note.destroy! }.not_to change {
          user.care_product_stock_movements.where(movement_type: "adjustment", adjustment_reason: "service_note_cancel").count
        }
      end

      it "detaches historical records from the deleted service note" do
        charge = service_note.formula_charges.first
        sale = service_note.care_product_sales.first
        movement = sale.stock_movement

        service_note.destroy!

        expect(charge.reload.service_note_id).to be_nil
        expect(sale.reload.service_note_id).to be_nil
        expect(movement.reload.service_note_id).to be_nil
      end

      it "preserves appointment references on historical records" do
        charge = service_note.formula_charges.first
        sale = service_note.care_product_sales.first
        movement = sale.stock_movement

        service_note.destroy!

        expect(charge.reload.appointment_id).to eq(historical_appointment.id)
        expect(sale.reload.appointment_id).to eq(historical_appointment.id)
        expect(movement.reload.appointment_id).to eq(historical_appointment.id)
      end
    end

    describe "#care_products_stock_available" do
      it "is valid when enough stock available" do
        note = build(:service_note, user: care_product.user,
          care_products: [ { "care_product_id" => care_product.id, "qty" => 5 } ])

        note.valid?

        expect(note.errors[:base]).to be_empty
      end

      it "adds validation error when stock insufficient" do
        note = build(:service_note, user: care_product.user,
          care_products: [ { "care_product_id" => care_product.id, "qty" => 20 } ])

        note.valid?

        expect(note.errors[:base]).to include("#{care_product.name}: only 10 left in stock")
      end

      describe "#care_products_are_active_for_stock_increase" do
        let(:care_product) { create(:care_product, user: user, purchase_price: 60, sale_price: 100, stock_quantity: 10) }
        let(:care_products) { [ { "care_product_id" => care_product.id, "price" => 100, "purchase_price" => 60, "qty" => 2 } ] }
        let(:service_note) { create(:service_note, user: user, client: client, appointment: appointment, care_products: care_products) }

        context "when product is archived" do
          before do
            service_note
            care_product.update!(archived_at: Time.current)
          end

          it "rejects quantity increase" do
            service_note.care_products = [ { "care_product_id" => care_product.id, "price" => 100, "purchase_price" => 60, "qty" => 3 } ]

            expect(service_note).not_to be_valid
            expect(service_note.errors[:base]).to include(I18n.t("care_products.errors.archived_product"))
          end

          it "allows quantity decrease" do
            service_note.care_products = [ { "care_product_id" => care_product.id, "price" => 100, "purchase_price" => 60, "qty" => 1 } ]

            expect(service_note).to be_valid
          end

          it "allows product removal" do
            service_note.care_products = []

            expect(service_note).to be_valid
          end

          it "allows sale price change" do
            service_note.care_products = [ { "care_product_id" => care_product.id, "price" => 120, "purchase_price" => 60, "qty" => 2 } ]

            expect(service_note).to be_valid
          end
        end

        context "when product is deleted" do
          before do
            service_note
            care_product.update!(deleted_at: Time.current)
          end

          it "rejects quantity increase" do
            service_note.care_products = [ { "care_product_id" => care_product.id, "price" => 100, "purchase_price" => 60, "qty" => 3 } ]

            expect(service_note).not_to be_valid
            expect(service_note.errors[:base]).to include(I18n.t("care_products.errors.deleted_product"))
          end

          it "allows quantity decrease" do
            service_note.care_products = [ { "care_product_id" => care_product.id, "price" => 100, "purchase_price" => 60, "qty" => 1 } ]

            expect(service_note).to be_valid
          end

          it "allows product removal" do
            service_note.care_products = []

            expect(service_note).to be_valid
          end

          it "allows sale price change" do
            service_note.care_products = [ { "care_product_id" => care_product.id, "price" => 120, "purchase_price" => 60, "qty" => 2 } ]

            expect(service_note).to be_valid
          end
        end
      end
    end

    describe "#available_stock_for" do
      it "returns current stock for new record" do
        note = build(:service_note)

        expect(note.send(:available_stock_for, care_product)).to eq(10)
      end

      it "includes previous quantity during update" do
        care_product.update!(stock_quantity: 7)

        note = build(:service_note)

        allow(note).to receive(:attribute_in_database)
          .with("care_products")
          .and_return([ { "care_product_id" => care_product.id, "qty" => 3 } ])

        expect(note.send(:available_stock_for, care_product)).to eq(10)
      end
    end
  end
end

require "rails_helper"

RSpec.describe ServiceNote, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:client) }
    it { is_expected.to belong_to(:appointment) }
    it { is_expected.to have_many(:formula_steps).dependent(:destroy) }
  end

  describe "scope .for_client" do
    let(:client) { create(:client) }
    let(:user) { client.user }

    let!(:older) do
      create(:service_note, client: client, user: user, created_at: 2.days.ago)
    end

    let!(:newer) do
      create(:service_note, client: client, user: user, created_at: 1.day.ago)
    end

    it "returns notes ordered by created_at desc" do
      expect(ServiceNote.for_client(client.id)).to eq([ newer, older ])
    end
  end

  describe "before_validation set_price_from_services" do
    let(:service1) { create(:service, price: 200) }
    let(:service2) { create(:service, price: 300) }

    it "sets price from services if present" do
      note = build(:service_note, price: nil)
      note.services = [ service1, service2 ]

      note.valid?

      expect(note.price).to eq(500)
    end

    it "does not override existing price" do
      note = build(:service_note, price: 100)
      note.services = [ service1 ]

      note.valid?

      expect(note.price).to eq(100)
    end

    it "keeps price nil if no services" do
      note = build(:service_note, price: nil)

      note.valid?

      expect(note.price).to be_nil
    end
  end

  describe "callbacks: notes sync" do
    let(:appointment) { create(:appointment, notes: "Appointment note") }

    context "copy_notes_from_appointment" do
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

    context "sync_appointment_notes" do
      it "updates appointment notes after save" do
        note = create(:service_note, appointment: appointment, notes: "New note")

        expect(appointment.reload.notes).to eq("New note")
      end

      it "does not update if notes are the same" do
        note = create(:service_note, appointment: appointment, notes: "Same note")

        appointment.update!(notes: "Same note")

        expect {
          note.save!
        }.not_to change { appointment.reload.notes }
      end
    end
  end

  describe "callbacks: services sync" do
    let(:appointment) { create(:appointment) }
    let(:service1) { create(:service, subtype: "Cut") }
    let(:service2) { create(:service, subtype: "Color") }

    context "sync_appointment_services" do
      it "syncs services to appointment after save" do
        note = create(:service_note, appointment: appointment)
        note.services = [ service1, service2 ]

        note.save!

        expect(appointment.reload.services).to match_array([ service1, service2 ])
      end

      it "updates service_name on appointment" do
        note = create(:service_note, appointment: appointment)
        note.services = [ service1, service2 ]

        note.save!

        expect(appointment.reload.service_name).to eq("Cut + Color")
      end
    end

    context "clear_appointment_services" do
      it "clears services on appointment when service_note destroyed" do
        note = create(:service_note, appointment: appointment)
        note.services = [ service1 ]
        note.save!

        note.destroy

        expect(appointment.reload.services).to be_empty
      end

      it "clears service_name when destroyed" do
        note = create(:service_note, appointment: appointment)
        note.services = [ service1 ]
        note.save!
        note.destroy

        expect(appointment.reload.service_name).to be_nil
      end
    end
  end

  describe "#service_names" do
    it "joins service subtypes with +" do
      service1 = create(:service, subtype: "Coloring")
      service2 = create(:service, subtype: "Haircut")

      note = create(:service_note)
      note.services = [ service1, service2 ]

      expect(note.service_names).to eq("Coloring + Haircut")
    end

    it "returns empty string when no services" do
      note = create(:service_note)

      expect(note.service_names).to eq("")
    end
  end

  describe "#all_services" do
    let(:appointment) { create(:appointment) }

    it "returns own services when present" do
      service1 = create(:service, subtype: "Cut")

      note = create(:service_note, appointment: appointment)
      note.services << service1

      expect(note.all_services).to match_array([ service1 ])
    end

    it "returns appointment services when own services absent" do
      service1 = create(:service, subtype: "Color")

      appointment.services << service1

      note = create(:service_note, appointment: appointment)

      expect(note.all_services).to match_array([ service1 ])
    end

    it "returns appointment services when note has no services and appointment has services" do
      service1 = create(:service, subtype: "Color")

      appointment = create(
        :appointment,
        main_service: service1
      )

      note = create(:service_note, appointment: appointment)

      expect(note.services).to be_empty
      expect(note.appointment.services).to match_array([ service1 ])

      expect(note.all_services).to match_array([ service1 ])
    end

    it "returns empty relation when appointment is nil" do
      user = create(:user)
      client = create(:client, user: user)

      note = build(
        :service_note,
        appointment: nil,
        user: user,
        client: client
      )

      expect(note.all_services).to be_empty
    end

    it "returns empty relation when no services anywhere" do
      note = create(:service_note, appointment: appointment)

      expect(note.all_services).to be_empty
    end
  end

  describe "#developer_total_amount" do
    it "returns sum of oxidant amounts" do
      note = create(:service_note)

      step1 = instance_double(FormulaStep, oxidant_amount: 10)
      step2 = instance_double(FormulaStep, oxidant_amount: 15)

      allow(note).to receive(:formula_steps).and_return([ step1, step2 ])

      expect(note.developer_total_amount).to eq(25)
    end

    it "returns 0 when no formula steps" do
      note = create(:service_note)

      expect(note.developer_total_amount).to eq(0)
    end
  end

  describe "#developer_total_price" do
    it "returns sum of oxidant total prices" do
      note = create(:service_note)

      step1 = instance_double(FormulaStep, oxidant_total_price: 50)
      step2 = instance_double(FormulaStep, oxidant_total_price: 75)

      allow(note).to receive(:formula_steps).and_return([ step1, step2 ])

      expect(note.developer_total_price).to eq(125)
    end

    it "returns 0 when no formula steps" do
      note = create(:service_note)

      expect(note.developer_total_price).to eq(0)
    end
  end

  describe "#care_products_total" do
    it "returns total from care products" do
      note = create(
        :service_note,
        care_products: [
          { "price" => 100, "qty" => 2 },
          { "price" => 50, "qty" => 3 }
        ]
      )

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
    it "returns services + developer + care products total" do
      service1 = create(:service, price: 100)
      service2 = create(:service, price: 200)

      note = create(
        :service_note,
        care_products: [
          { "price" => 50, "qty" => 2 }
        ]
      )

      note.services = [ service1, service2 ]

      allow(note).to receive(:developer_total_price).and_return(75)

      expect(note.final_price).to eq(475)
    end

    it "returns only services total when others absent" do
      service1 = create(:service, price: 300)

      note = create(:service_note)
      note.services << service1

      allow(note).to receive(:developer_total_price).and_return(0)
      allow(note).to receive(:care_products_total).and_return(0)

      expect(note.final_price).to eq(300)
    end
  end

  describe "#appointment_date" do
    it "returns appointment appointment_date" do
      appointment = create(:appointment, appointment_date: Date.current + 3.days)

      note = create(:service_note, appointment: appointment)

      expect(note.appointment_date).to eq(appointment.appointment_date)
    end
  end

  describe "validations" do
    it "validates uniqueness of appointment_id" do
      appointment = create(:appointment)

      create(:service_note, appointment: appointment)

      duplicate = build(:service_note, appointment: appointment)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:appointment_id]).to be_present
    end
  end

  describe "#decorated_photos" do
    it "decorates all photos" do
      note = create(:service_note)

      file = fixture_file_upload(
        Rails.root.join("spec/fixtures/files/test_image.jpg"),
        "image/jpg"
      )

      note.photos.attach(file)

      decorated = double("decorated_photo")

      allow(PhotoDecorator)
        .to receive(:decorate)
        .and_return(decorated)

      expect(note.decorated_photos).to eq([ decorated ])
    end
  end

  describe "sync_appointment_services edge cases" do
    let(:appointment) { create(:appointment) }

    it "does nothing when appointment absent" do
      note = build(:service_note, appointment: nil)

      expect {
        note.send(:sync_appointment_services)
      }.not_to raise_error
    end

    it "does not overwrite appointment services when services empty" do
      service = create(:service)

      appointment.services << service

      note = create(:service_note, appointment: appointment)

      expect {
        note.save!
      }.not_to change {
        appointment.reload.services.to_a
      }
    end
  end

  describe "sync_appointment_notes edge cases" do
    it "does nothing when appointment absent" do
      note = build(:service_note, appointment: nil)

      expect {
        note.send(:sync_appointment_notes)
      }.not_to raise_error
    end
  end

  describe "clear_appointment_services edge cases" do
    it "does nothing when appointment absent" do
      note = build(:service_note, appointment: nil)

      expect {
        note.send(:clear_appointment_services)
      }.not_to raise_error
    end
  end
end

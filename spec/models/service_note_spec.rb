require "rails_helper"

RSpec.describe ServiceNote, type: :model do
  let(:appointment) { create(:appointment) }
  let(:service) { create(:service, subtype: "Color", price: 100) }
  let(:extra_service) { create(:service, subtype: "Cut", price: 200) }
  let(:note) { create(:service_note, appointment: appointment) }
  let(:step1) { instance_double(FormulaStep, oxidant_amount: 10, oxidant_total_price: 50) }
  let(:step2) { instance_double(FormulaStep, oxidant_amount: 15, oxidant_total_price: 75) }

  def stub_totals(note, developer: 0, care: 0)
    allow(note).to receive(:developer_total_price).and_return(developer)

    allow(note).to receive(:care_products_total).and_return(care)
  end

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:client) }
    it { is_expected.to belong_to(:appointment) }
    it { is_expected.to have_many(:formula_steps).dependent(:destroy) }
  end

  describe "scope .for_client" do
    let(:client) { create(:client) }
    let(:user) { client.user }
    let!(:older) { create(:service_note, client: client, user: user, created_at: 2.days.ago) }
    let!(:newer) { create(:service_note, client: client, user: user, created_at: 1.day.ago) }

    it "returns notes ordered by created_at desc" do
      expect(ServiceNote.for_client(client.id)).to eq([ newer, older ])
    end
  end

  describe "validations" do
    it "validates uniqueness of appointment_id" do
      create(:service_note, appointment: appointment)

      duplicate = build(:service_note, appointment: appointment)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:appointment_id]).to be_present
    end

    it "is invalid without services" do
      invalid_appointment = create(:appointment, main_service: nil)

      invalid_note = build(:service_note, :without_services, appointment: invalid_appointment)

      expect(invalid_note).not_to be_valid
      expect(invalid_note.errors[:base]).to include(
        I18n.t("service_notes.errors.services_required")
      )
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
      invalid_note = build(:service_note, :without_services, price: nil)

      invalid_note.valid?

      expect(invalid_note.price).to be_nil
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
        }.not_to change {
          appointment.reload.notes
        }
      end
    end
  end

  describe "callbacks: services sync" do
    context "sync_appointment_services" do
      it "syncs services to appointment after save" do
        note.services = [ service, extra_service ]

        note.save!

        expect(appointment.reload.services).to match_array([ service, extra_service ])
      end

      it "updates service_name on appointment" do
        note.services = [ service, extra_service ]

        note.save!

        expect(appointment.reload.service_name).to eq("Color + Cut")
      end
    end

    context "clear_appointment_services" do
      it "clears services on appointment when service_note destroyed" do
        note.services = [ service ]

        note.save!
        note.destroy

        expect(appointment.reload.services).to be_empty
      end

      it "clears service_name when destroyed" do
        note.services = [ service ]

        note.save!
        note.destroy

        expect(appointment.reload.service_name).to be_nil
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
    let(:appointment) { create(:appointment, main_service: nil) }

    it "returns own services when present" do
      note.services = [ service ]

      expect(note.all_services).to match_array([ service ])
    end

    it "returns appointment services when own services absent" do
      appointment.services = [ service ]

      built_note = build(:service_note, appointment: appointment, user: appointment.user, client: appointment.client)

      built_note.services = []

      expect(built_note.services).to be_empty
      expect(built_note.all_services).to match_array([ service ])
    end

    it "returns appointment services when note has no services and appointment has services" do
      appointment.services = [ service ]

      built_note = build(:service_note, appointment: appointment, user: appointment.user, client: appointment.client)

      built_note.services = []

      expect(built_note.services).to be_empty
      expect(built_note.appointment.services).to match_array([ service ])
      expect(built_note.all_services).to match_array([ service ])
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
      allow(note).to receive(:formula_steps).and_return([ step1, step2 ])

      expect(note.developer_total_amount).to eq(25)
    end

    it "returns 0 when no formula steps" do
      expect(note.developer_total_amount).to eq(0)
    end
  end

  describe "#developer_total_price" do
    it "returns sum of oxidant total prices" do
      allow(note).to receive(:formula_steps).and_return([ step1, step2 ])

      expect(note.developer_total_price).to eq(125)
    end

    it "returns 0 when no formula steps" do
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
      note.services = [ service, extra_service ]

      stub_totals(note, developer: 75)

      allow(note).to receive(:care_products_total).and_return(100)

      expect(note.final_price).to eq(475)
    end

    it "returns only services total when others absent" do
      note.services = [ service ]

      stub_totals(note)

      expect(note.final_price).to eq(100)
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
      file = fixture_file_upload(
        Rails.root.join("spec/fixtures/files/test_image.jpg"),
        "image/jpg"
      )

      note.photos.attach(file)

      decorated = double("decorated_photo")

      allow(PhotoDecorator).to receive(:decorate).and_return(decorated)

      expect(note.decorated_photos).to eq([ decorated ])
    end
  end

  describe "sync_appointment_services edge cases" do
    it "does nothing when appointment absent" do
      note = build(:service_note, appointment: nil)

      expect { note.send(:sync_appointment_services) }.not_to raise_error
    end

    it "does not overwrite appointment services when services empty" do
      appointment.services << service

      empty_note = ServiceNote.new(appointment: appointment, user: appointment.user, client: appointment.client)

      allow(empty_note).to receive(:services).and_return(Service.none)

      expect {
        empty_note.send(:sync_appointment_services)
      }.not_to change {
        appointment.reload.services.to_a
      }
    end
  end

  describe "sync_appointment_notes edge cases" do
    it "does nothing when appointment absent" do
      note = build(:service_note, appointment: nil)

      expect { note.send(:sync_appointment_notes) }.not_to raise_error
    end
  end

  describe "clear_appointment_services edge cases" do
    it "does nothing when appointment absent" do
      note = build(:service_note, appointment: nil)

      expect { note.send(:clear_appointment_services) }.not_to raise_error
    end
  end
end

require "rails_helper"

RSpec.describe ServiceNote, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:client) }
    it { is_expected.to belong_to(:appointment).optional }
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

  describe "#short_title" do
    it "returns haircut title" do
      note = build(:service_note, service_type: "haircut")
      expect(note.short_title).to eq("Стрижка")
    end

    it "returns coloring title" do
      note = build(:service_note, service_type: "coloring")
      expect(note.short_title).to eq("Фарбування")
    end

    it "returns care title" do
      note = build(:service_note, service_type: "care")
      expect(note.short_title).to eq("Догляд")
    end

    it "capitalizes unknown service types" do
      note = build(:service_note, service_type: "custom")
      expect(note.short_title).to eq("Custom")
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
end

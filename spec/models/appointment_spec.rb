# spec/models/appointment_spec.rb

require "rails_helper"

RSpec.describe Appointment do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }
  let(:client) { create(:client, user: user) }
  let(:main_service) { create(:service, user: user, subtype: "Coloring", price: 100) }
  let(:extra_service) { create(:service, user: user, subtype: "Haircut", price: 200) }
  let(:appointment) { create(:appointment, user: user, client: client, main_service: main_service) }

  describe "validations" do
    subject do
      build(
        :appointment,
        user: user,
        client: client,
        appointment_date: Date.current,
        appointment_time: "10:00",
        main_service: main_service
      )
    end

    it { is_expected.to validate_presence_of(:appointment_date) }
    it { is_expected.to validate_presence_of(:appointment_time) }

    it "validates uniqueness of appointment_time scoped to appointment_date" do
      create(
        :appointment,
        user: user,
        client: client,
        appointment_date: Date.current,
        appointment_time: "10:00",
        main_service: main_service
      )

      duplicate = build(
        :appointment,
        user: user,
        client: client,
        appointment_date: Date.current,
        appointment_time: "10:00",
        main_service: main_service
      )

      expect(duplicate).not_to be_valid
    end
  end

  describe "callbacks" do
    it "sets default end_time before validation" do
      appointment = build(
        :appointment,
        user: user,
        client: client,
        appointment_time: Time.zone.parse("10:00"),
        end_time: nil,
        main_service: main_service
      )

      appointment.valid?

      expect(appointment.end_time.strftime("%H:%M")).to eq("10:30")
    end
  end

  describe "#total_price" do
    it "returns sum of service prices" do
      appointment = create(
        :appointment,
        user: user,
        client: client,
        main_service: main_service,
        extra_services: [ extra_service ]
      )

      expect(appointment.total_price).to eq(300)
    end
  end

  describe "#combined_service_name" do
    it "joins service subtypes" do
      appointment = create(
        :appointment,
        user: user,
        client: client,
        main_service: main_service,
        extra_services: [ extra_service ]
      )

      expect(appointment.combined_service_name).to eq("Coloring + Haircut")
    end

    it "returns service_note services when present" do
      service_note = create(
        :service_note,
        services_count: 0,
        appointment: appointment,
        user: user,
        client: client
      )

      service_note.services = [ extra_service, main_service ]
      service_note.save!

      expect(
        appointment.reload
          .combined_service_name
          .split(" + ")
      ).to contain_exactly(
        "Haircut",
        "Coloring"
      )
    end

    it "falls back to appointment services if service_note has no services" do
      create(
        :service_note,
        :without_services,
        appointment: appointment,
        user: user,
        client: client
      )

      expect(appointment.reload.combined_service_name).to eq("Coloring")
    end
  end

  describe "#as_calendar_json" do
    it "returns formatted calendar hash" do
      json = appointment.as_calendar_json

      expect(json[:id]).to eq(appointment.id)
      expect(json[:client_name]).to eq(client.full_name)
      expect(json[:service]).to eq(appointment.combined_service_name)
    end

    it "returns nil service_note_id when no service note exists" do
      json = appointment.as_calendar_json

      expect(json[:service_note_id]).to be_nil
    end

    it "handles nil end_time" do
      appointment.update_column(:end_time, nil)

      json = appointment.as_calendar_json

      expect(json[:end]).to include("T")
    end

    it "includes service_note_id when present" do
      service_note = create(
        :service_note,
        appointment: appointment,
        user: user,
        client: client
      )

      json = appointment.as_calendar_json

      expect(json[:service_note_id]).to eq(service_note.id)
    end
  end

  describe ".available_slots" do
    let(:date) { Date.current }

    let!(:slot_rule) do
      instance_double(
        SlotRule,
        active_on?: true,
        slots_for: [
          {
            start: Time.zone.parse("#{date} 10:00"),
            end: Time.zone.parse("#{date} 11:00")
          },
          {
            start: Time.zone.parse("#{date} 11:00"),
            end: Time.zone.parse("#{date} 11:30")
          }
        ]
      )
    end

    before do
      slot_rules_relation = double

      allow(user).to receive(:slot_rules).and_return(slot_rules_relation)
      allow(slot_rules_relation).to receive(:select).and_return([ slot_rule ])
    end

    it "returns all slots when there are no appointments" do
      slots = described_class.available_slots(user, date)

      expect(slots.length).to eq(2)
    end

    it "removes conflicting slots" do
      create(
        :appointment,
        user: user,
        client: client,
        appointment_date: date,
        appointment_time: Time.zone.parse("10:00"),
        end_time: Time.zone.parse("10:45")
      )

      slots = described_class.available_slots(user, date)

      expect(slots.length).to eq(1)
      expect(slots.first[:start].strftime("%H:%M")).to eq("11:00")
    end

    it "keeps non-conflicting slots" do
      create(
        :appointment,
        user: user,
        client: client,
        appointment_date: date,
        appointment_time: Time.zone.parse("12:00"),
        end_time: Time.zone.parse("12:30")
      )

      slots = described_class.available_slots(user, date)

      expect(slots.length).to eq(2)
    end

    it "moves pointer past finished appointments" do
      create(
        :appointment,
        user: user,
        client: client,
        appointment_date: date,
        appointment_time: Time.zone.parse("09:00"),
        end_time: Time.zone.parse("09:30")
      )

      slots = described_class.available_slots(user, date)

      expect(slots.length).to eq(2)
    end
  end

  describe ".by_date" do
    it "returns appointments for given date" do
      today = create(
        :appointment,
        user: user,
        client: client,
        appointment_date: Date.current,
        main_service: main_service
      )

      create(
        :appointment,
        user: user,
        client: client,
        appointment_date: Date.tomorrow,
        main_service: main_service
      )

      result = described_class.by_date(Date.current)

      expect(result).to include(today)
      expect(result.count).to eq(1)
    end
  end

  describe ".grouped_by_month" do
    before do
      travel_to Time.zone.local(2026, 1, 1)
    end

    after { travel_back }

    it "groups appointments by appointment month" do
      appointment_in_first_month = create(
        :appointment,
        user: user,
        client: client,
        appointment_date: Date.new(2026, 3, 10),
        main_service: main_service
      )

      appointment_in_second_month = create(
        :appointment,
        user: user,
        client: client,
        appointment_date: Date.new(2026, 4, 10),
        main_service: main_service
      )

      grouped = described_class.grouped_by_month(
        [ appointment_in_first_month, appointment_in_second_month ]
      )

      expect(grouped.keys).to contain_exactly("March 2026", "April 2026")
      expect(grouped["March 2026"]).to contain_exactly(appointment_in_first_month)
      expect(grouped["April 2026"]).to contain_exactly(appointment_in_second_month)
    end
  end

  describe "callbacks: service_note sync" do
    let(:service_note) { create(:service_note, appointment: appointment, client: client, user: user) }

    describe "#sync_service_note_client" do
      it "updates service_note client when appointment client changes" do
        service_note

        new_client = create(:client, user: user)

        appointment.update_column(:client_id, new_client.id)

        appointment.send(:sync_service_note_client)

        expect(service_note.reload.client).to eq(new_client)
      end

      it "does nothing if no service_note" do
        appointment_without_note = create(:appointment, user: user, client: client)

        expect {
          appointment_without_note.update!(
            client: create(:client, user: user)
          )
        }.not_to raise_error
      end
    end

    describe "#sync_service_note_notes" do
      it "updates service_note notes after save" do
        service_note.update_column(:notes, nil)
        appointment.update!(notes: "Updated from appointment")

        expect(service_note.reload.notes).to eq("Updated from appointment")
      end

      it "does not update if notes are the same" do
        service_note.update!(notes: "Same note")
        appointment.update!(notes: "Same note")

        expect { appointment.save! }.not_to change { service_note.reload.notes }
      end

      it "does nothing if no service_note" do
        appointment_without_note = create(
          :appointment,
          user: user,
          client: client,
          notes: "Test"
        )

        expect { appointment_without_note.save! }.not_to raise_error
      end
    end
  end

  describe "private validations and callbacks" do
    describe "#set_service_name" do
      it "sets service_name from service_ids when services are empty" do
        appointment = build(:appointment, user: user, client: client, main_service: nil)
        appointment.service_ids = [ main_service.id ]
        appointment.save!

        expect(appointment.service_name).to eq("Coloring")
      end
    end

    describe "#valid_date" do
      it "is invalid when appointment_date is in the past" do
        appointment = build(
          :appointment,
          user: user,
          client: client,
          appointment_date: Date.yesterday,
          main_service: nil
        )

        expect(appointment).not_to be_valid

        expect(appointment.errors[:appointment_date]).to include("can't be in the past")
      end
    end

    describe "#valid_end_time" do
      it "is invalid when end_time equals appointment_time" do
        time = Time.zone.parse("10:00")

        appointment = build(
          :appointment,
          user: user,
          client: client,
          appointment_time: time,
          end_time: time,
          main_service: nil
        )

        expect(appointment).not_to be_valid
        expect(appointment.errors[:end_time]).to include("must be later than start time")
      end
    end

    describe "#time_step_interval" do
      it "is invalid when appointment_time is not divisible by 5 minutes" do
        appointment = build(
          :appointment,
          user: user,
          client: client,
          appointment_time: Time.zone.parse("10:03"),
          end_time: Time.zone.parse("10:33"),
          main_service: nil
        )

        expect(appointment).not_to be_valid
        expect(appointment.errors[:appointment_time]).to include("must be in 5-minute intervals")
      end
    end
  end
end

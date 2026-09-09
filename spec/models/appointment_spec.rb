# spec/models/appointment_spec.rb

require "rails_helper"

RSpec.describe Appointment do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }
  let(:client) { create(:client, user: user) }
  let(:main_service) { create(:service, user: user, subtype: "Coloring", price: 100) }
  let(:extra_service) { create(:service, user: user, subtype: "Haircut", price: 200) }
  let(:appointment) { create(:appointment, user: user, client: client, main_service: main_service) }

  def appointment_at(date:, time:, end_time:, service: main_service)
    create(
      :appointment,
      user: user,
      client: client,
      appointment_date: date,
      appointment_time: Time.zone.parse(time),
      end_time: Time.zone.parse(end_time),
      main_service: service
    )
  end

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
        main_service: main_service
      )

      # the factory's own after(:build) hook fills end_time when blank, so
      # clear it again here to exercise the model's before_validation callback
      appointment.end_time = nil

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

  describe "#client_name" do
    it "returns the associated client's full name" do
      expect(appointment.client_name).to eq(client.full_name)
    end

    it "returns nil when there is no client" do
      appointment.client = nil

      expect(appointment.client_name).to be_nil
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

  describe "date/time scopes" do
    describe ".past and .future" do
      it "splits today's appointments by whether they already ended" do
        past_day = travel_to(Time.zone.local(2026, 3, 3, 12, 0, 0)) do
          appointment_at(date: Date.current, time: "09:00", end_time: "09:30")
        end

        travel_to Time.zone.local(2026, 3, 4, 12, 0, 0) do
          finished = appointment_at(date: Date.current, time: "09:00", end_time: "09:30")
          upcoming = appointment_at(date: Date.current, time: "14:00", end_time: "14:30")
          future_day = appointment_at(date: Date.tomorrow, time: "09:00", end_time: "09:30")

          expect(described_class.past).to include(finished, past_day)
          expect(described_class.past).not_to include(upcoming, future_day)

          expect(described_class.future).to include(upcoming, future_day)
          expect(described_class.future).not_to include(finished, past_day)
        end
      end

      it "treats a nil end_time as still upcoming" do
        travel_to Time.zone.local(2026, 3, 4, 12, 0, 0) do
          appointment = create(
            :appointment,
            user: user,
            client: client,
            appointment_date: Date.current,
            appointment_time: Time.zone.parse("14:00"),
            main_service: main_service
          )

          appointment.update_column(:end_time, nil)

          expect(described_class.future).to include(appointment)
        end
      end
    end

    describe ".for_styles" do
      it "orders by date/time desc and includes service_note photos" do
        earlier = create(
          :appointment,
          user: user,
          client: client,
          appointment_date: Date.current,
          main_service: main_service
        )

        later = create(
          :appointment,
          user: user,
          client: client,
          appointment_date: Date.tomorrow,
          main_service: main_service
        )

        result = described_class.for_styles

        expect(result.to_a).to eq([ later, earlier ])
      end
    end

    describe ".with_client" do
      it "includes the client association" do
        appointment

        expect(described_class.with_client.first.association(:client)).to be_loaded
      end
    end

    describe ".ordered" do
      it "orders by date/time descending" do
        earlier = create(
          :appointment,
          user: user,
          client: client,
          appointment_date: Date.current,
          main_service: main_service
        )

        later = create(
          :appointment,
          user: user,
          client: client,
          appointment_date: Date.tomorrow,
          main_service: main_service
        )

        expect(described_class.ordered.to_a).to eq([ later, earlier ])
      end
    end

    describe ".search" do
      it "returns all appointments when query is blank" do
        appointment

        expect(described_class.search(nil)).to include(appointment)
        expect(described_class.search("")).to include(appointment)
      end

      it "matches by client first name" do
        expect(described_class.search(client.first_name)).to include(appointment)
      end

      it "matches by client last name" do
        expect(described_class.search(client.last_name)).to include(appointment)
      end

      it "matches by client phone" do
        expect(described_class.search(client.phone)).to include(appointment)
      end

      it "matches by service_name" do
        appointment

        expect(described_class.search(appointment.service_name)).to include(appointment)
      end

      it "matches by notes" do
        appointment.update!(notes: "Unique note text")

        expect(described_class.search("Unique note text")).to include(appointment)
      end

      it "returns nothing when nothing matches" do
        appointment

        expect(described_class.search("no-such-match-zzz")).to be_empty
      end
    end

    describe ".for_year" do
      it "returns all when year is blank" do
        appointment

        expect(described_class.for_year(nil)).to include(appointment)
      end

      it "filters appointments within the given year" do
        travel_to Time.zone.local(2026, 1, 1) do
          in_year = create(
            :appointment,
            user: user,
            client: client,
            appointment_date: Date.new(2026, 6, 1),
            main_service: main_service
          )

          out_of_year = create(
            :appointment,
            user: user,
            client: client,
            appointment_date: Date.new(2027, 6, 1),
            main_service: main_service
          )

          result = described_class.for_year(2026)

          expect(result).to include(in_year)
          expect(result).not_to include(out_of_year)
        end
      end
    end

    describe ".for_month" do
      it "returns all when month is blank" do
        appointment

        expect(described_class.for_month(2026, nil)).to include(appointment)
      end

      it "filters appointments within the given year/month" do
        travel_to Time.zone.local(2026, 1, 1) do
          in_month = create(
            :appointment,
            user: user,
            client: client,
            appointment_date: Date.new(2026, 6, 15),
            main_service: main_service
          )

          out_of_month = create(
            :appointment,
            user: user,
            client: client,
            appointment_date: Date.new(2026, 7, 1),
            main_service: main_service
          )

          result = described_class.for_month(2026, 6)

          expect(result).to include(in_month)
          expect(result).not_to include(out_of_month)
        end
      end
    end

    describe ".for_categories" do
      it "returns all when categories are blank" do
        appointment

        expect(described_class.for_categories(nil)).to include(appointment)
        expect(described_class.for_categories([])).to include(appointment)
      end

      it "filters appointments by service category" do
        coloring_service = create(:service, user: user, category: "Coloring", subtype: "Balayage", price: 100)

        matching = create(
          :appointment,
          user: user,
          client: client,
          appointment_date: Date.current + 5.days,
          main_service: coloring_service
        )

        non_matching = appointment

        result = described_class.for_categories([ "Coloring" ])

        expect(result).to include(matching)
        expect(result).not_to include(non_matching)
      end
    end

    describe ".for_services" do
      it "returns all when service_ids are blank" do
        appointment

        expect(described_class.for_services(nil)).to include(appointment)
        expect(described_class.for_services([])).to include(appointment)
      end

      it "filters appointments by service id" do
        other_appointment = create(
          :appointment,
          user: user,
          client: client,
          appointment_date: Date.current + 5.days,
          main_service: extra_service
        )

        result = described_class.for_services([ main_service.id ])

        expect(result).to include(appointment)
        expect(result).not_to include(other_appointment)
      end
    end
  end

  describe ".available_years" do
    it "returns distinct years sorted descending" do
      travel_to(Time.zone.local(2024, 5, 1)) do
        create(:appointment, user: user, client: client, appointment_date: Date.current, main_service: main_service)
      end

      travel_to Time.zone.local(2026, 5, 1) do
        create(:appointment, user: user, client: client, appointment_date: Date.current, main_service: main_service)
        create(:appointment, user: user, client: client, appointment_date: Date.new(2026, 6, 1),
main_service: main_service)
      end

      expect(described_class.available_years(described_class.all)).to eq([ 2026, 2024 ])
    end
  end

  describe ".statistics" do
    it "returns total, current_year and current_month counts" do
      travel_to(Time.zone.local(2025, 1, 1)) do
        create(:appointment, user: user, client: client, appointment_date: Date.current, main_service: main_service)
      end

      travel_to Time.zone.local(2026, 3, 4) do
        create(:appointment, user: user, client: client, appointment_date: Date.current, main_service: main_service)
        create(:appointment, user: user, client: client, appointment_date: Date.new(2026, 6, 1),
main_service: main_service)

        stats = described_class.statistics(described_class.all, year: 2026, month: 3)

        expect(stats).to eq(total: 3, current_year: 2, current_month: 1)
      end
    end
  end

  describe ".available_time_ranges" do
    it "returns empty when user has no active slot rules" do
      travel_to Time.zone.local(2026, 3, 4, 8, 0, 0) do
        expect(described_class.available_time_ranges(user, Date.current)).to eq([])
      end
    end

    it "returns the full working range when there are no appointments" do
      travel_to Time.zone.local(2026, 3, 4, 6, 0, 0) do
        create(
          :slot_rule,
          user: user,
          start_time: Time.zone.parse("09:00"),
          end_time: Time.zone.parse("10:00"),
          weekdays: %w[wednesday]
        )

        ranges = described_class.available_time_ranges(user, Date.current)

        expect(ranges.length).to eq(1)
        expect(ranges.first[:start].strftime("%H:%M")).to eq("09:00")
        expect(ranges.first[:end].strftime("%H:%M")).to eq("10:00")
      end
    end

    it "clamps the start of today's range to the current time, rounded up to 5 minutes" do
      travel_to Time.zone.local(2026, 3, 4, 9, 12, 0) do
        create(
          :slot_rule,
          user: user,
          start_time: Time.zone.parse("09:00"),
          end_time: Time.zone.parse("10:00"),
          weekdays: %w[wednesday]
        )

        ranges = described_class.available_time_ranges(user, Date.current)

        expect(ranges.first[:start].strftime("%H:%M")).to eq("09:15")
      end
    end

    it "returns no ranges once the working day is already over" do
      travel_to Time.zone.local(2026, 3, 4, 23, 0, 0) do
        create(
          :slot_rule,
          user: user,
          start_time: Time.zone.parse("09:00"),
          end_time: Time.zone.parse("10:00"),
          weekdays: %w[wednesday]
        )

        expect(described_class.available_time_ranges(user, Date.current)).to eq([])
      end
    end

    it "carves out booked appointments and skips appointments outside the working window" do
      travel_to Time.zone.local(2026, 3, 4, 6, 0, 0) do
        create(
          :slot_rule,
          user: user,
          start_time: Time.zone.parse("09:00"),
          end_time: Time.zone.parse("12:00"),
          weekdays: %w[wednesday]
        )

        appointment_at(date: Date.current, time: "10:00", end_time: "10:30")
        appointment_at(date: Date.current, time: "07:00", end_time: "07:30")
        appointment_at(date: Date.current, time: "13:00", end_time: "13:30")

        ranges = described_class.available_time_ranges(user, Date.current)

        formatted = ranges.map { |r| [ r[:start].strftime("%H:%M"), r[:end].strftime("%H:%M") ] }

        expect(formatted).to eq([ [ "09:00", "10:00" ], [ "10:30", "12:00" ] ])
      end
    end

    it "combines ranges from multiple active slot rules, sorted by start" do
      travel_to Time.zone.local(2026, 3, 4, 6, 0, 0) do
        create(
          :slot_rule,
          user: user,
          start_time: Time.zone.parse("14:00"),
          end_time: Time.zone.parse("15:00"),
          weekdays: %w[wednesday]
        )

        create(
          :slot_rule,
          user: user,
          start_time: Time.zone.parse("09:00"),
          end_time: Time.zone.parse("10:00"),
          weekdays: %w[wednesday]
        )

        ranges = described_class.available_time_ranges(user, Date.current)

        formatted = ranges.map { |r| [ r[:start].strftime("%H:%M"), r[:end].strftime("%H:%M") ] }

        expect(formatted).to eq([ [ "09:00", "10:00" ], [ "14:00", "15:00" ] ])
      end
    end

    it "does not clamp the start time for a date other than today" do
      travel_to Time.zone.local(2026, 3, 4, 9, 30, 0) do
        create(
          :slot_rule,
          user: user,
          start_time: Time.zone.parse("09:00"),
          end_time: Time.zone.parse("10:00"),
          weekdays: %w[thursday]
        )

        ranges = described_class.available_time_ranges(user, Date.current + 1.day)

        expect(ranges.first[:start].strftime("%H:%M")).to eq("09:00")
      end
    end

    it "skips slot rules that produce no slots" do
      travel_to Time.zone.local(2026, 3, 4, 6, 0, 0) do
        empty_rule = instance_double(SlotRule, active_on?: true, slots_for: [])

        allow(user).to receive(:slot_rules).and_return([ empty_rule ])

        expect(described_class.available_time_ranges(user, Date.current)).to eq([])
      end
    end

    it "ignores appointments with a blank end_time" do
      travel_to Time.zone.local(2026, 3, 4, 6, 0, 0) do
        create(
          :slot_rule,
          user: user,
          start_time: Time.zone.parse("09:00"),
          end_time: Time.zone.parse("10:00"),
          weekdays: %w[wednesday]
        )

        appt = create(
          :appointment,
          user: user,
          client: client,
          appointment_date: Date.current,
          appointment_time: Time.zone.parse("09:15"),
          main_service: main_service
        )

        appt.update_column(:end_time, nil)

        ranges = described_class.available_time_ranges(user, Date.current)

        formatted = ranges.map { |r| [ r[:start].strftime("%H:%M"), r[:end].strftime("%H:%M") ] }

        expect(formatted).to eq([ [ "09:00", "10:00" ] ])
      end
    end

    it "produces no free ranges when appointments cover the window back-to-back" do
      travel_to Time.zone.local(2026, 3, 4, 6, 0, 0) do
        create(
          :slot_rule,
          user: user,
          start_time: Time.zone.parse("09:00"),
          end_time: Time.zone.parse("10:00"),
          weekdays: %w[wednesday]
        )

        appointment_at(date: Date.current, time: "09:00", end_time: "09:30")
        appointment_at(date: Date.current, time: "09:30", end_time: "10:00")

        expect(described_class.available_time_ranges(user, Date.current)).to eq([])
      end
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

      expect(grouped.keys).to contain_exactly(Date.new(2026, 3, 1), Date.new(2026, 4, 1))
      expect(grouped[Date.new(2026, 3, 1)]).to contain_exactly(appointment_in_first_month)
      expect(grouped[Date.new(2026, 4, 1)]).to contain_exactly(appointment_in_second_month)
    end

    it "orders months descending, most recent first" do
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

      expect(grouped.keys).to eq([ Date.new(2026, 4, 1), Date.new(2026, 3, 1) ])
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

      it "falls back to Service.where(id: service_ids) when the services association is empty" do
        appointment = build(:appointment, user: user, client: client, main_service: nil)
        appointment.service_ids = [ main_service.id ]

        allow(appointment).to receive(:services).and_return(Service.none)

        appointment.send(:set_service_name)

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

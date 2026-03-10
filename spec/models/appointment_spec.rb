require "rails_helper"

RSpec.describe Appointment, type: :model do
  let(:user) { create(:user) }
  let(:client) { create(:client, user: user) }
  let(:main_service) { create(:service, user: user) }

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
      s1 = create(:service, price: 100, user: user)
      s2 = create(:service, price: 200, user: user)

      appointment = create(
        :appointment,
        user: user,
        client: client,
        main_service: s1,
        extra_services: [ s2 ]
      )

      expect(appointment.total_price).to eq(300)
    end
  end

  describe "#combined_service_name" do
    it "joins service subtypes" do
      s1 = create(:service, subtype: "Coloring", user: user)
      s2 = create(:service, subtype: "Haircut", user: user)

      appointment = create(
        :appointment,
        user: user,
        client: client,
        main_service: s1,
        extra_services: [ s2 ]
      )

      expect(appointment.combined_service_name).to eq("Coloring + Haircut")
    end
  end

  describe "#as_calendar_json" do
    it "returns formatted calendar hash" do
      appointment = create(
        :appointment,
        user: user,
        client: client,
        appointment_date: Date.current,
        appointment_time: "10:00",
        main_service: main_service
      )

      json = appointment.as_calendar_json

      expect(json[:id]).to eq(appointment.id)
      expect(json[:client_name]).to eq(client.full_name)
      expect(json[:service]).to eq(appointment.service_name)
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
end

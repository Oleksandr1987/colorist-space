require "rails_helper"

RSpec.describe AppointmentServicesRelation do
  describe "associations" do
    it { is_expected.to belong_to(:appointment).inverse_of(:appointment_services_relations) }
    it { is_expected.to belong_to(:service).inverse_of(:appointment_services_relations) }
  end

  describe "scope .by_service_type" do
    let(:service_coloring) { create(:service, service_type: "service") }
    let(:service_preparation) { create(:service, service_type: "preparation") }

    let(:appointment) { create(:appointment, main_service: service_coloring) }

    let!(:main_relation) do
      appointment.appointment_services_relations.first
    end

    before do
      create(:appointment_services_relation,
        appointment: appointment,
        service: service_preparation
      )
    end

    it "returns relations for given service type" do
      result = described_class.by_service_type("service")

      expect(result).to contain_exactly(main_relation)
    end
  end

  describe "scope .for_user" do
    let(:main_user) { create(:user) }
    let(:add_user) { create(:user) }

    let(:service) { create(:service) }

    let(:main_appointment) do
      create(:appointment,
        user: main_user,
        main_service: service,
        appointment_time: Time.zone.parse("10:00"),
        end_time: Time.zone.parse("10:30")
      )
    end

    let(:add_appointment) do
      create(:appointment,
        user: add_user,
        main_service: service,
        appointment_time: Time.zone.parse("11:00"),
        end_time: Time.zone.parse("11:30")
      )
    end

    let!(:main_relation) do
      main_appointment.appointment_services_relations.first
    end

    before do
      add_appointment.appointment_services_relations.first
    end

    it "returns relations for given user" do
      result = described_class.for_user(main_user.id)

      expect(result).to contain_exactly(main_relation)
    end
  end
end

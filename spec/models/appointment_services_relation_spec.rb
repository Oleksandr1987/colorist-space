require "rails_helper"

RSpec.describe AppointmentServicesRelation, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:appointment).inverse_of(:appointment_services_relations) }
    it { is_expected.to belong_to(:service).inverse_of(:appointment_services_relations) }
  end

  describe "scope .by_service_type" do
    let(:service_coloring) { create(:service, service_type: "service") }
    let(:service_preparation) { create(:service, service_type: "preparation") }

    let(:appointment) { create(:appointment, main_service: service_coloring) }

    let!(:relation1) do
      appointment.appointment_services_relations.first
    end

    let!(:relation2) do
      create(:appointment_services_relation,
        appointment: appointment,
        service: service_preparation
      )
    end

    it "returns relations for given service type" do
      result = described_class.by_service_type("service")

      expect(result).to contain_exactly(relation1)
    end
  end

  describe "scope .for_user" do
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }

    let(:service) { create(:service) }

    let(:appointment1) do
      create(:appointment,
        user: user1,
        main_service: service,
        appointment_time: Time.zone.parse("10:00"),
        end_time: Time.zone.parse("10:30")
      )
    end

    let(:appointment2) do
      create(:appointment,
        user: user2,
        main_service: service,
        appointment_time: Time.zone.parse("11:00"),
        end_time: Time.zone.parse("11:30")
      )
    end

    let!(:relation1) do
      appointment1.appointment_services_relations.first
    end

    let!(:relation2) do
      appointment2.appointment_services_relations.first
    end

    it "returns relations for given user" do
      result = described_class.for_user(user1.id)

      expect(result).to contain_exactly(relation1)
    end
  end
end

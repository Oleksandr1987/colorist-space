require "rails_helper"

RSpec.describe AppointmentServicesRelation do
  describe "associations" do
    it { is_expected.to belong_to(:appointment).inverse_of(:appointment_services_relations) }
    it { is_expected.to belong_to(:service).inverse_of(:appointment_services_relations) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:appointment) }
    it { is_expected.to validate_presence_of(:service) }
    it { is_expected.to validate_presence_of(:price) }
    it { is_expected.to validate_presence_of(:service_name) }
    it { is_expected.to validate_presence_of(:service_category) }
  end

  describe "historical snapshots" do
    let(:user) { create(:user) }
    let(:service) { create(:service, user: user, category: "coloring", subtype: "Balayage", price: 500) }
    let(:appointment) { create(:appointment, user: user, client: create(:client, user: user), main_service: nil) }
    let(:relation) { create(:appointment_services_relation, appointment: appointment, service: service) }

    it "snapshots the service price" do
      expect(relation.price).to eq(500)
    end

    it "snapshots the service name" do
      expect(relation.service_name).to eq("Balayage")
    end

    it "snapshots the service category" do
      expect(relation.service_category).to eq("coloring")
    end

    it "preserves historical values after the catalog service changes" do
      relation

      service.update!(category: "treatment", subtype: "Repair Treatment", price: 900)

      relation.reload

      expect(relation.price).to eq(500)
      expect(relation.service_name).to eq("Balayage")
      expect(relation.service_category).to eq("coloring")
    end
  end

  describe "scope .for_user" do
    let(:main_user) { create(:user) }
    let(:add_user) { create(:user) }
    let(:service) { create(:service, user: main_user, category: "coloring") }
    let(:add_service) { create(:service, user: add_user, category: "coloring") }

    let(:main_appointment) do
      create(:appointment, user: main_user,
        main_service: service, appointment_time: Time.zone.parse("10:00"), end_time: Time.zone.parse("10:30"))
    end
    let(:add_appointment) do
      create(:appointment, user: add_user,
        main_service: add_service, appointment_time: Time.zone.parse("11:00"), end_time: Time.zone.parse("11:30"))
    end

    let!(:main_relation) { main_appointment.appointment_services_relations.first }

    before do
      add_appointment.appointment_services_relations.first
    end

    it "returns relations for given user" do
      result = described_class.for_user(main_user.id)

      expect(result).to contain_exactly(main_relation)
    end
  end

  describe "scope .for_categories" do
    let(:user) { create(:user) }
    let(:client) { create(:client, user: user) }
    let(:coloring_service) { create(:service, user: user, category: "coloring", subtype: "Balayage") }
    let(:haircut_service) { create(:service, user: user, category: "haircut", subtype: "Haircut") }

    let!(:coloring_relation) do
      appointment =
        create(:appointment, user: user, client: client,
          main_service: coloring_service, appointment_time: Time.zone.parse("10:00"), end_time: Time.zone.parse("10:30"))

      appointment.appointment_services_relations.first
    end

    let!(:haircut_relation) do
      appointment =
        create(:appointment, user: user, client: client,
          main_service: haircut_service, appointment_time: Time.zone.parse("11:00"), end_time: Time.zone.parse("11:30"))

      appointment.appointment_services_relations.first
    end

    it "filters by historical service category" do
      expect(described_class.for_categories([ "coloring" ])).to contain_exactly(coloring_relation)
    end

    it "does not depend on the current service category" do
      coloring_service.update!(category: "treatment")

      expect(described_class.for_categories([ "coloring" ])).to contain_exactly(coloring_relation)
    end

    it "returns all relations when categories are blank" do
      expect(described_class.for_categories([])).to contain_exactly(coloring_relation, haircut_relation)
    end
  end
end

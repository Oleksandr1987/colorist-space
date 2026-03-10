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

  describe "#build_default_formula" do
    let(:service_note) { build(:service_note) }

    it "builds a formula step" do
      service_note.build_default_formula

      expect(service_note.formula_steps.size).to eq(1)
    end

    it "builds a formula ingredient inside step" do
      step = service_note.build_default_formula

      expect(step.formula_ingredients.size).to eq(1)
    end
  end

  describe "before_validation set_price_from_appointment" do
    let(:service) { create(:service) }

    let(:appointment) do
      create(:appointment, main_service: service)
    end

    before do
      allow(appointment).to receive(:total_price).and_return(500)
    end

    it "copies price from appointment if price blank" do
      note = build(:service_note, appointment: appointment, price: nil)

      note.valid?

      expect(note.price).to eq(500)
    end

    it "does not override existing price" do
      note = build(:service_note, appointment: appointment, price: 200)

      note.valid?

      expect(note.price).to eq(200)
    end
  end
end

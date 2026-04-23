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
end

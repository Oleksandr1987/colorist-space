require "rails_helper"

RSpec.describe Service do
  include ActiveSupport::Testing::TimeHelpers

  before do
    travel_to(Time.zone.local(2026, 1, 1, 10, 0, 0))
  end

  after do
    travel_back
  end

  describe "validations" do
    it "requires category for service" do
      service = build(:service, service_type: "service", category: nil)

      expect(service).not_to be_valid
      expect(service.errors[:category]).to be_present
    end
  end

  describe "#sync_name" do
    it "does not override name when subtype is blank" do
      service = build(:service, subtype: nil, name: "Custom Name")

      service.valid?

      expect(service.name).to eq("Custom Name")
    end
  end

  describe ".for_filter" do
    let(:user) { create(:user) }

    it "returns appointment services ordered by category/subtype, filtered by category" do
      haircut = create(:service, user: user, service_type: "service", category: "haircut", subtype: "Short")
      coloring = create(:service, user: user, service_type: "service", category: "coloring", subtype: "Balayage")

      result = described_class.for_filter([ "haircut" ])

      expect(result).to include(haircut)
      expect(result).not_to include(coloring)
    end

    it "returns all appointment services when no categories given" do
      haircut = create(:service, user: user, service_type: "service", category: "haircut", subtype: "Short")

      expect(described_class.for_filter).to include(haircut)
    end
  end

  describe ".for_user_and_category" do
    it "returns the user's appointment services for a given category, ordered by subtype" do
      user = create(:user)
      other_user = create(:user)

      matching = create(:service, user: user, service_type: "service", category: "haircut", subtype: "Short")
      create(:service, user: user, service_type: "service", category: "coloring", subtype: "Balayage")
      create(:service, user: other_user, service_type: "service", category: "haircut", subtype: "Short")

      result = described_class.for_user_and_category(user, "haircut")

      expect(result).to contain_exactly(matching)
    end
  end

  describe ".categories_for_user" do
    it "returns distinct sorted categories used by the given user's appointment services" do
      user = create(:user)

      create(:service, user: user, service_type: "service", category: "haircut", subtype: "Short")
      create(:service, user: user, service_type: "service", category: "coloring", subtype: "Balayage")
      create(:service, user: user, service_type: "service", category: "haircut", subtype: "Long")

      expect(described_class.categories_for_user(user)).to eq([ "coloring", "haircut" ])
    end
  end

  describe ".normalize_category" do
    it "returns nil when category is blank" do
      expect(described_class.normalize_category(nil)).to be_nil
      expect(described_class.normalize_category("")).to be_nil
    end

    it "returns the normalized value when it matches a known category" do
      expect(described_class.normalize_category("Haircut")).to eq("haircut")
      expect(described_class.normalize_category(" COLORING ")).to eq("coloring")
    end

    it "matches by translated category label" do
      translated = I18n.t("services.categories.haircut")

      expect(described_class.normalize_category(translated)).to eq("haircut")
    end

    it "returns the original value when nothing matches" do
      expect(described_class.normalize_category("totally-unknown")).to eq("totally-unknown")
    end
  end
end

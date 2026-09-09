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
      service = build(
        :service,
        service_type: "service",
        category: nil
      )

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

  describe ".apply_income_filters" do
    it "returns the scope unchanged when no filters are given" do
      service = create(:service, user: create(:user))

      expect(described_class.apply_income_filters({})).to include(service)
    end
  end

  describe "income scopes / helpers" do
    let(:user) { create(:user) }
    let(:other_user) { create(:user) }

    let(:client) { create(:client, user: user) }
    let(:other_client) { create(:client, user: other_user) }

    let(:main_service) do
      create(:service,
        user: user,
        service_type: "service",
        category: "Haircut",
        subtype: "A",
        price: 100
      )
    end

    let(:main_service_b) do
      create(:service,
        user: user,
        service_type: "service",
        category: "Coloring",
        subtype: "B",
        price: 200
      )
    end

    let(:appointment_one) { Date.current + 9.days }
    let(:appointment_two) { Date.current + 11.days }
    let(:appointment_out_of_range) { Date.current + 31.days }

    before do
      create(:appointment,
        user: user,
        client: client,
        appointment_date: appointment_one,
        appointment_time: Time.zone.parse("10:00"),
        end_time: Time.zone.parse("10:30"),
        main_service: main_service
      )

      create(:appointment,
        user: user,
        client: client,
        appointment_date: appointment_two,
        appointment_time: Time.zone.parse("11:00"),
        end_time: Time.zone.parse("11:30"),
        main_service: main_service_b
      )

      # appointment outside reporting range
      create(:appointment,
        user: user,
        client: client,
        appointment_date: appointment_out_of_range,
        appointment_time: Time.zone.parse("10:00"),
        end_time: Time.zone.parse("10:30"),
        main_service: main_service
      )

      # appointment belonging to another user
      other_users_service = create(:service,
        user: other_user,
        service_type: "service",
        category: "Haircut",
        subtype: "X",
        price: 999
      )

      create(:appointment,
        user: other_user,
        client: other_client,
        appointment_date: appointment_one,
        appointment_time: Time.zone.parse("12:00"),
        end_time: Time.zone.parse("12:30"),
        main_service: other_users_service
      )
    end

    it ".income_for_user_between returns only services from user's appointments within range" do
      from = Date.current
      to   = Date.current + 30.days

      scope = described_class.income_for_user_between(user, from, to)

      expect(scope).to include(main_service, main_service_b)
      expect(scope.pluck(:price)).not_to include(999)
    end

    it ".apply_income_filters filters category/subtype only when service_type == service" do
      from = Date.current
      to   = Date.current + 30.days

      base = described_class.income_for_user_between(user, from, to)

      filtered = base.apply_income_filters(
        service_type: "service",
        category: "Haircut",
        subtype: "A"
      )

      expect(filtered).to include(main_service)
      expect(filtered).not_to include(main_service_b)
    end

    it ".grouped_income groups by subtype for service_type service" do
      from = Date.current
      to   = Date.current + 30.days

      scope = described_class
        .income_for_user_between(user, from, to)
        .apply_income_filters(service_type: "service")

      grouped = described_class.grouped_income(scope, "service")

      expect(grouped.keys).to include("A", "B")
      expect(grouped["A"]).to eq(100)
      expect(grouped["B"]).to eq(200)
    end

    it ".monthly_income groups by service_type then by month label" do
      from = Date.current
      to   = Date.current + 30.days

      scope = described_class.income_for_user_between(user, from, to)

      monthly = described_class.monthly_income(scope)

      expect(monthly.keys).to include("service")

      month_label = appointment_one.strftime("%B %Y")

      expect(monthly["service"].keys).to include(month_label)

      expect(monthly.dig("service", appointment_out_of_range.strftime("%B %Y"))).to be_nil
    end

    it ".grouped_income groups by name when service_type is present but not service" do
      # service_type is now restricted to "service" by validation, but rows created
      # before that constraint (or the branch handling them) can still exist, so we
      # bypass validation here to exercise that legacy code path.
      product = build(
        :service,
        user: user,
        service_type: "product",
        name: "Some Product",
        subtype: "n/a",
        price: 42
      )
      product.save!(validate: false)

      grouped = described_class.grouped_income(described_class.where(id: product.id), "product")

      expect(grouped).to eq({ "Some Product" => 42 })
    end

    it ".grouped_income groups by service_type when no service_type filter given" do
      grouped = described_class.grouped_income(described_class.where(id: main_service.id), nil)

      expect(grouped).to eq({ "service" => 100 })
    end
  end

  describe ".for_filter" do
    let(:user) { create(:user) }

    it "returns appointment services ordered by category/subtype, filtered by category" do
      haircut = create(:service, user: user, service_type: "service", category: "Haircut", subtype: "Short")
      coloring = create(:service, user: user, service_type: "service", category: "Coloring", subtype: "Balayage")

      result = described_class.for_filter([ "Haircut" ])

      expect(result).to include(haircut)
      expect(result).not_to include(coloring)
    end

    it "returns all appointment services when no categories given" do
      haircut = create(:service, user: user, service_type: "service", category: "Haircut", subtype: "Short")

      expect(described_class.for_filter).to include(haircut)
    end
  end

  describe ".for_user_and_category" do
    it "returns the user's appointment services for a given category, ordered by subtype" do
      user = create(:user)
      other_user = create(:user)

      matching = create(:service, user: user, service_type: "service", category: "Haircut", subtype: "Short")
      create(:service, user: user, service_type: "service", category: "Coloring", subtype: "Balayage")
      create(:service, user: other_user, service_type: "service", category: "Haircut", subtype: "Short")

      result = described_class.for_user_and_category(user, "Haircut")

      expect(result).to contain_exactly(matching)
    end
  end

  describe ".categories_for_user" do
    it "returns distinct sorted categories used by the given user's appointment services" do
      user = create(:user)

      create(:service, user: user, service_type: "service", category: "Haircut", subtype: "Short")
      create(:service, user: user, service_type: "service", category: "Coloring", subtype: "Balayage")
      create(:service, user: user, service_type: "service", category: "Haircut", subtype: "Long")

      expect(described_class.categories_for_user(user)).to eq([ "Coloring", "Haircut" ])
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

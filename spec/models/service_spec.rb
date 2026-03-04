require "rails_helper"

RSpec.describe Service, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  around do |example|
    travel_to(Time.zone.local(2026, 1, 1, 10, 0, 0)) do
      example.run
    end
  end

  describe "validations" do
    it "requires category only for service_type == service" do
      service = build(:service, service_type: "service", category: nil)
      expect(service).not_to be_valid
      expect(service.errors[:category]).to be_present

      prep = build(:service, :preparation, category: nil)
      expect(prep).to be_valid
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

    let(:prep) { create(:service, :preparation, user: user, price: 50) }

    let(:appointment_in_range_1) { Date.current + 9.days }
    let(:appointment_in_range_2) { Date.current + 11.days }
    let(:appointment_out_of_range) { Date.current + 31.days }

    before do
      create(:appointment,
        user: user,
        client: client,
        appointment_date: appointment_in_range_1,
        appointment_time: Time.zone.parse("10:00"),
        end_time: Time.zone.parse("10:30"),
        main_service: main_service,
        extra_services: [ prep ]
      )

      create(:appointment,
        user: user,
        client: client,
        appointment_date: appointment_in_range_2,
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
        appointment_date: appointment_in_range_1,
        appointment_time: Time.zone.parse("12:00"),
        end_time: Time.zone.parse("12:30"),
        main_service: other_users_service
      )
    end

    it ".income_for_user_between returns only services from user's appointments within range" do
      from = Date.current
      to   = Date.current + 30.days

      scope = described_class.income_for_user_between(user, from, to)

      expect(scope).to include(main_service, main_service_b, prep)
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
      expect(filtered).not_to include(prep)
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

      expect(monthly.keys).to include("service", "preparation")

      month_label = appointment_in_range_1.strftime("%B %Y")

      expect(monthly["service"].keys).to include(month_label)
      expect(monthly["preparation"].keys).to include(month_label)

      expect(monthly.dig("service", appointment_out_of_range.strftime("%B %Y"))).to be_nil
    end
  end
end

require "rails_helper"

RSpec.describe SlotRule, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    subject { build(:slot_rule) }

    it { is_expected.to validate_presence_of(:start_time) }
    it { is_expected.to validate_presence_of(:end_time) }
    it { is_expected.to validate_presence_of(:weekdays) }
  end

  describe "custom validations" do
    it "is invalid when end_time before start_time" do
      rule = build(
        :slot_rule,
        start_time: Time.zone.parse("12:00"),
        end_time: Time.zone.parse("10:00")
      )

      expect(rule).not_to be_valid
      expect(rule.errors[:end_time])
        .to include("must be after start time")
    end

    it "is valid when end_time after start_time" do
      rule = build(
        :slot_rule,
        start_time: Time.zone.parse("09:00"),
        end_time: Time.zone.parse("10:00")
      )

      expect(rule).to be_valid
    end

    it "does nothing when start_time blank" do
      rule = build(
        :slot_rule,
        start_time: nil,
        end_time: Time.zone.parse("10:00")
      )

      rule.valid?

      expect(rule.errors[:end_time])
        .not_to include("must be after start time")
    end

    it "does nothing when end_time blank" do
      rule = build(
        :slot_rule,
        start_time: Time.zone.parse("09:00"),
        end_time: nil
      )

      rule.valid?

      expect(rule.errors[:end_time])
        .not_to include("must be after start time")
    end
  end

  describe "#schedule" do
    it "returns nil when rule blank" do
      rule = build(:slot_rule, rule: nil)

      expect(rule.schedule).to be_nil
    end

    it "returns IceCube::Schedule when rule present" do
      slot_rule = create(:slot_rule)

      expect(slot_rule.schedule).to be_a(IceCube::Schedule)
    end
  end

  describe "#active_on?" do
    it "returns true when schedule occurs on date" do
      slot_rule = create(
        :slot_rule,
        weekdays: [ Date.current.strftime("%A").downcase ]
      )

      expect(slot_rule.active_on?(Date.current)).to eq(true)
    end

    it "returns false when schedule does not occur on date" do
      slot_rule = create(
        :slot_rule,
        weekdays: [ "monday" ]
      )

      date = Date.parse("2026-05-12") # tuesday

      expect(slot_rule.active_on?(date)).to eq(false)
    end

    it "returns nil when schedule absent" do
      slot_rule = build(:slot_rule, rule: nil)

      allow(slot_rule).to receive(:schedule).and_return(nil)

      expect(slot_rule.active_on?(Date.current)).to be_nil
    end
  end

  describe "#slots_for" do
    it "returns empty array when inactive on date" do
      slot_rule = create(
        :slot_rule,
        weekdays: [ "monday" ]
      )

      date = Date.parse("2026-05-12") # tuesday

      expect(slot_rule.slots_for(date)).to eq([])
    end

    it "generates slots for active date" do
      today_name = Date.current.strftime("%A").downcase

      slot_rule = create(
        :slot_rule,
        start_time: Time.zone.parse("09:00"),
        end_time: Time.zone.parse("09:15"),
        weekdays: [ today_name ]
      )

      slots = slot_rule.slots_for(Date.current, 5)

      expect(slots.size).to eq(3)

      expect(slots.first[:start].strftime("%H:%M")).to eq("09:00")
      expect(slots.first[:end].strftime("%H:%M")).to eq("09:05")

      expect(slots.last[:start].strftime("%H:%M")).to eq("09:10")
      expect(slots.last[:end].strftime("%H:%M")).to eq("09:15")
    end

    it "supports custom step_minutes" do
      today_name = Date.current.strftime("%A").downcase

      slot_rule = create(
        :slot_rule,
        start_time: Time.zone.parse("09:00"),
        end_time: Time.zone.parse("10:00"),
        weekdays: [ today_name ]
      )

      slots = slot_rule.slots_for(Date.current, 30)

      expect(slots.size).to eq(2)

      expect(slots.first[:start].strftime("%H:%M")).to eq("09:00")
      expect(slots.first[:end].strftime("%H:%M")).to eq("09:30")

      expect(slots.last[:start].strftime("%H:%M")).to eq("09:30")
      expect(slots.last[:end].strftime("%H:%M")).to eq("10:00")
    end
  end

  describe "before_validation #build_schedule" do
    it "builds rule from weekdays and start_time" do
      slot_rule = build(
        :slot_rule,
        weekdays: %w[monday friday]
      )

      slot_rule.valid?

      expect(slot_rule.rule).to be_present
    end

    it "does nothing when start_time blank" do
      slot_rule = build(
        :slot_rule,
        start_time: nil
      )

      slot_rule.valid?

      expect(slot_rule.rule).to be_nil
    end

    it "does nothing when weekdays blank" do
      slot_rule = build(
        :slot_rule,
        weekdays: []
      )

      slot_rule.valid?

      expect(slot_rule.rule).to be_nil
    end
  end

  describe "#time_on" do
    it "builds datetime on given date with time values" do
      slot_rule = build(:slot_rule)

      result = slot_rule.send(
        :time_on,
        Date.parse("2026-05-11"),
        Time.zone.parse("14:30")
      )

      expect(result.hour).to eq(14)
      expect(result.min).to eq(30)
    end
  end

  describe "#generate_slots" do
    it "generates slots until end_at" do
      slot_rule = build(:slot_rule)

      start_at = Time.zone.parse("2026-05-11 09:00")
      end_at = Time.zone.parse("2026-05-11 09:15")

      slots = slot_rule.send(
        :generate_slots,
        start_at,
        end_at,
        5
      )

      expect(slots.size).to eq(3)

      expect(slots).to eq([
        {
          start: Time.zone.parse("2026-05-11 09:00"),
          end: Time.zone.parse("2026-05-11 09:05")
        },
        {
          start: Time.zone.parse("2026-05-11 09:05"),
          end: Time.zone.parse("2026-05-11 09:10")
        },
        {
          start: Time.zone.parse("2026-05-11 09:10"),
          end: Time.zone.parse("2026-05-11 09:15")
        }
      ])
    end

    it "returns empty array when start equals end" do
      slot_rule = build(:slot_rule)

      time = Time.zone.parse("2026-05-11 09:00")

      slots = slot_rule.send(
        :generate_slots,
        time,
        time,
        5
      )

      expect(slots).to eq([])
    end
  end
end

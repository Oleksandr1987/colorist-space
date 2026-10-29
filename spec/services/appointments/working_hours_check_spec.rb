# frozen_string_literal: true

require "rails_helper"

RSpec.describe Appointments::WorkingHoursCheck do
  subject(:result) { described_class.new(user: user, date: date, start_time: start_time, end_time: end_time).call }

  let(:user) { create(:user) }
  let(:date) { Date.new(2026, 10, 26) }
  let(:start_time) { nil }
  let(:end_time) { nil }

  def create_rule(start_at:, end_at:, weekdays: %w[monday])
    create(:slot_rule, user: user, start_time: Time.zone.parse(start_at), end_time: Time.zone.parse(end_at), weekdays: weekdays)
  end

  describe "#call" do
    context "when there are no slot rules" do
      it "returns day_off" do
        expect(result).to eq(status: "day_off")
      end
    end

    context "when the date is a day off" do
      before { create_rule(start_at: "09:00", end_at: "18:00", weekdays: %w[tuesday]) }

      it "returns day_off" do
        expect(result).to eq(status: "day_off")
      end
    end

    context "when the date is a working day" do
      before { create_rule(start_at: "09:00", end_at: "18:00") }

      it "returns available working intervals without times" do
        expect(result).to eq(status: "ok", intervals: [ { start: "09:00", end: "18:00" } ])
      end

      context "when only start time is provided" do
        let(:start_time) { "10:00" }

        it "returns ok" do
          expect(result[:status]).to eq("ok")
        end
      end

      context "when only end time is provided" do
        let(:end_time) { "11:00" }

        it "returns ok" do
          expect(result[:status]).to eq("ok")
        end
      end

      context "when appointment is inside working hours" do
        let(:start_time) { "10:00" }
        let(:end_time) { "11:00" }

        it "returns ok with intervals" do
          expect(result).to eq(status: "ok", intervals: [ { start: "09:00", end: "18:00" } ])
        end
      end

      context "when appointment matches working hours exactly" do
        let(:start_time) { "09:00" }
        let(:end_time) { "18:00" }

        it "returns ok" do
          expect(result[:status]).to eq("ok")
        end
      end

      context "when appointment starts before working hours" do
        let(:start_time) { "08:30" }
        let(:end_time) { "10:00" }

        it "returns outside_hours" do
          expect(result[:status]).to eq("outside_hours")
        end
      end

      context "when appointment ends after working hours" do
        let(:start_time) { "17:00" }
        let(:end_time) { "19:00" }

        it "returns outside_hours" do
          expect(result[:status]).to eq("outside_hours")
        end
      end

      context "when appointment is completely outside working hours" do
        let(:start_time) { "20:00" }
        let(:end_time) { "21:00" }

        it "returns outside_hours with available intervals" do
          expect(result).to eq(status: "outside_hours", intervals: [ { start: "09:00", end: "18:00" } ])
        end
      end

      context "when start and end times are equal" do
        let(:start_time) { "10:00" }
        let(:end_time) { "10:00" }

        it "returns invalid_time" do
          expect(result).to eq(status: "invalid_time")
        end
      end

      context "when end time is before start time" do
        let(:start_time) { "12:00" }
        let(:end_time) { "11:00" }

        it "returns invalid_time" do
          expect(result).to eq(status: "invalid_time")
        end
      end

      context "when times are Time objects" do
        let(:start_time) { Time.zone.parse("10:00") }
        let(:end_time) { Time.zone.parse("11:00") }

        it "returns ok" do
          expect(result[:status]).to eq("ok")
        end
      end
    end

    context "when working intervals are adjacent" do
      before do
        create_rule(start_at: "09:00", end_at: "12:00")
        create_rule(start_at: "12:00", end_at: "18:00")
      end

      it "merges adjacent intervals" do
        expect(result[:intervals]).to eq([ { start: "09:00", end: "18:00" } ])
      end

      context "when appointment crosses the interval boundary" do
        let(:start_time) { "11:00" }
        let(:end_time) { "13:00" }

        it "returns ok" do
          expect(result[:status]).to eq("ok")
        end
      end
    end

    context "when working intervals overlap" do
      before do
        create_rule(start_at: "09:00", end_at: "14:00")
        create_rule(start_at: "12:00", end_at: "18:00")
      end

      it "merges overlapping intervals" do
        expect(result[:intervals]).to eq([ { start: "09:00", end: "18:00" } ])
      end
    end

    context "when working intervals have a gap" do
      before do
        create_rule(start_at: "09:00", end_at: "12:00")
        create_rule(start_at: "13:00", end_at: "18:00")
      end

      it "keeps intervals separate" do
        expect(result[:intervals]).to eq([ { start: "09:00", end: "12:00" }, { start: "13:00", end: "18:00" } ])
      end

      context "when appointment crosses the gap" do
        let(:start_time) { "11:00" }
        let(:end_time) { "14:00" }

        it "returns outside_hours" do
          expect(result[:status]).to eq("outside_hours")
        end
      end

      context "when appointment is inside the second interval" do
        let(:start_time) { "14:00" }
        let(:end_time) { "16:00" }

        it "returns ok" do
          expect(result[:status]).to eq("ok")
        end
      end
    end

    context "when rules belong to another user" do
      before { create(:slot_rule, weekdays: %w[monday]) }

      it "returns day_off" do
        expect(result).to eq(status: "day_off")
      end
    end

  context "when time parameters are malformed" do
    before { create(:slot_rule, user: user, weekdays: %w[monday], start_time: "09:00", end_time: "18:00") }

    [ [ "abc", "11:00" ], [ "10:00", "invalid" ], [ [ "10:00" ], "11:00" ], [ "25:00", "11:00" ], [ "10:00", "12:99" ] ].each do |from, to|
      context "with start_time #{from.inspect} and end_time #{to.inspect}" do
        let(:start_time) { from }
        let(:end_time) { to }

        it "returns invalid_time" do
          expect(result).to eq(status: "invalid_time")
        end
      end
    end
  end
  end
end

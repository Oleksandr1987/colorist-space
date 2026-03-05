require "rails_helper"

RSpec.describe Expense, type: :model do
  describe "validations" do
    it "is invalid if spent_on is in the future" do
      expense = build(:expense, spent_on: Date.today + 1)

      expect(expense).not_to be_valid
      expect(expense.errors[:spent_on]).to include("Please select a date in the past or today")
    end
  end

  describe "scopes" do
    let(:user) { create(:user) }
    let(:other_user) { create(:user) }

    it ".for_user_between returns only records for the user within range" do
      from = Date.new(2026, 1, 1)
      to   = Date.new(2026, 1, 31)

      in_range = create(:expense, user: user, spent_on: Date.new(2026, 1, 10))
      out_of_range = create(:expense, user: user, spent_on: Date.new(2026, 2, 1))
      other_users = create(:expense, user: other_user, spent_on: Date.new(2026, 1, 10))

      result = described_class.for_user_between(user, from, to)

      expect(result).to contain_exactly(in_range)
      expect(result).not_to include(out_of_range, other_users) # “не робить зайвого”
    end

    it ".apply_category_filter filters only when category is present" do
      rent = create(:expense, category: "Оренда")
      tools = create(:expense, category: "Інструменти")

      expect(described_class.apply_category_filter("Оренда")).to include(rent)
      expect(described_class.apply_category_filter("Оренда")).not_to include(tools)

      # no filter → returns relation unchanged (не “ламає”)
      expect(described_class.apply_category_filter(nil)).to include(rent, tools)
    end
  end

  describe "analytics helpers" do
    it ".grouped_expenses groups by category and sums amount" do
      create(:expense, category: "Оренда", amount: 100)
      create(:expense, category: "Оренда", amount: 50)
      create(:expense, category: "Інше", amount: 10)

      grouped = described_class.grouped_expenses(Expense.all)

      expect(grouped).to eq({ "Оренда" => 150, "Інше" => 10 })
    end

    it ".total_expenses sums amount" do
      create(:expense, amount: 40)
      create(:expense, amount: 60)

      expect(described_class.total_expenses(Expense.all)).to eq(100)
    end

    it ".monthly_expenses groups by month label" do
      create(:expense, spent_on: Date.new(2026, 1, 5))
      create(:expense, spent_on: Date.new(2026, 1, 20))
      create(:expense, spent_on: Date.new(2026, 2, 1))

      grouped = described_class.monthly_expenses(Expense.all)

      expect(grouped.keys).to contain_exactly("February 2026", "January 2026")
      expect(grouped["January 2026"].size).to eq(2)
      expect(grouped["February 2026"].size).to eq(1)
    end
  end
end

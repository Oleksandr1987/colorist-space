require "rails_helper"

RSpec.describe Expense, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "constants" do
    it "defines categories list" do
      expect(described_class::CATEGORIES).to include("rent", "materials", "other")
    end
  end

  describe "validations" do
    it "is invalid without category" do
      expense = build(:expense, category: nil)

      expect(expense).not_to be_valid
      expect(expense.errors[:category]).to be_present
    end

    it "is invalid if amount is not positive integer" do
      expense = build(:expense, amount: -10)

      expect(expense).not_to be_valid
      expect(expense.errors[:amount]).to be_present
    end

    it "is invalid without spent_on" do
      expense = build(:expense, spent_on: nil)

      expect(expense).not_to be_valid
      expect(expense.errors[:spent_on]).to be_present
    end

    it "is invalid if spent_on is in the future" do
      expense = build(:expense, spent_on: Date.today + 1)

      expect(expense).not_to be_valid
      expect(expense.errors[:spent_on]).to include("Please select a date in the past or today")
    end
  end

  describe "scopes" do
    let(:user) { create(:user) }
    let(:other_user) { create(:user) }

    it ".ordered_by_date sorts expenses by spent_on desc" do
      older = create(:expense, spent_on: Date.new(2026, 1, 1))
      newer = create(:expense, spent_on: Date.new(2026, 2, 1))

      result = described_class.ordered_by_date

      expect(result.first).to eq(newer)
      expect(result.last).to eq(older)
    end

    it ".for_user_between returns only records for the user within range" do
      from = Date.new(2026, 1, 1)
      to   = Date.new(2026, 1, 31)

      in_range = create(:expense, user: user, spent_on: Date.new(2026, 1, 10))
      out_of_range = create(:expense, user: user, spent_on: Date.new(2026, 2, 1))
      other_users = create(:expense, user: other_user, spent_on: Date.new(2026, 1, 10))

      result = described_class.for_user_between(user, from, to)

      expect(result).to contain_exactly(in_range)
      expect(result).not_to include(out_of_range, other_users)
    end

    it ".apply_category_filter filters only when category is present" do
      rent = create(:expense, category: "rent")
      tools = create(:expense, category: "tools")

      expect(described_class.apply_category_filter("rent")).to include(rent)
      expect(described_class.apply_category_filter("rent")).not_to include(tools)

      expect(described_class.apply_category_filter(nil)).to include(rent, tools)
    end
  end

  describe "analytics helpers" do
    it ".grouped_expenses groups by category and sums amount" do
      create(:expense, category: "rent", amount: 100)
      create(:expense, category: "rent", amount: 50)
      create(:expense, category: "other", amount: 10)

      grouped = described_class.grouped_expenses(Expense.all)

      expect(grouped).to eq({ "rent" => 150, "other" => 10 })
    end

    it ".total_expenses sums amount" do
      create(:expense, amount: 40)
      create(:expense, amount: 60)

      expect(described_class.total_expenses(Expense.all)).to eq(100)
    end

    it ".monthly_expenses groups by month label" do
      I18n.with_locale(:en) do
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
end

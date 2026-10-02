# frozen_string_literal: true

puts "🌱 Seeding expenses..."

user = User.find_by!(email: "demo@colorist.space")

expense_templates = {
  "rent" => { amount: 12_000, note: "Studio rent" },
  "materials" => { amount: 3_500, note: "Salon materials" },
  "advertising" => { amount: 2_000, note: "Advertising" },
  "transport" => { amount: 1_200, note: "Transport" },
  "tools" => { amount: 1_500, note: "Tools" },
  "utilities" => { amount: 2_500, note: "Utilities" },
  "other" => { amount: 800, note: "Other expenses" }
}

12.times do |month_offset|
  month = Date.current << month_offset

  expense_templates.each_with_index do |(category, attrs), index|
    day = [ index + 1, month.end_of_month.day ].min
    spent_on = month.change(day: day)
    spent_on = Date.current if spent_on > Date.current

    expense =
      user.expenses.find_or_initialize_by(
        category: category,
        spent_on: spent_on,
        note: attrs[:note]
      )

    expense.amount = attrs[:amount]
    expense.save!
  end
end

puts "✅ Expenses seeded"

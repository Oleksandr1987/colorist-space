# frozen_string_literal: true

require "faker"

puts "🌱 Running seeds for #{Rails.env} environment..."

unless Rails.env.development?
  puts "ℹ️ Demo seeds are available only in development"
  return
end

%w[
  users
  services
  formula_products
  care_products
  clients
  slot_rules
  expenses
  appointments
  service_notes
].each do |seed|
  puts "→ #{seed.humanize}"
  load Rails.root.join("db/seeds/#{seed}.rb")
end

puts "🎉 Seeding completed successfully"

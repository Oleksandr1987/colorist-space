# frozen_string_literal: true

puts "🌱 Seeding users..."

demo_user = User.find_or_initialize_by(email: "demo@colorist.space")

demo_user.assign_attributes(
  name: "Demo User",
  phone: "+380500000000",
  tos_agreement: true
)

if demo_user.new_record?
  demo_user.password = "Password123!"
  demo_user.password_confirmation = "Password123!"
end

demo_user.save!

puts "✅ Demo user ready: #{demo_user.email}"

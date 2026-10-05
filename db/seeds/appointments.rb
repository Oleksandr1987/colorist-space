# frozen_string_literal: true

puts "🌱 Seeding appointments..."

user = User.find_by!(email: "demo@colorist.space")

clients = user.clients.order(:id).to_a
services = user.services.appointment_services.ordered_for_filter.to_a

raise "Demo clients are missing" if clients.empty?
raise "Demo services are missing" if services.empty?

appointment_times = [
  [ "09:00", "10:00" ],
  [ "11:00", "12:00" ],
  [ "14:00", "15:00" ],
  [ "16:00", "17:00" ]
]

find_appointment = lambda do |date, time|
  hour, minute = time.split(":").map(&:to_i)

  user.appointments.where(appointment_date: date).find do |appointment|
    appointment.appointment_time.hour == hour &&
      appointment.appointment_time.min == minute
  end
end

12.times do |month_offset|
  month = Date.current.beginning_of_month << month_offset

  [ 5, 12, 19, 26 ].each_with_index do |day, index|
    next if day > month.end_of_month.day

    appointment_date = month.change(day: day)
    next if appointment_date > Date.current

    start_time, end_time = appointment_times[index]

    client = clients[(month_offset * 4 + index) % clients.size]

    selected_services = [
      services[(month_offset * 4 + index) % services.size]
    ]

    appointment =
      find_appointment.call(appointment_date, start_time) ||
      user.appointments.new

    appointment.assign_attributes(
      client: client,
      appointment_date: appointment_date,
      appointment_time: start_time,
      end_time: end_time
    )

    appointment.notes ||= "Demo historical appointment"

    appointment.save!

    appointment.sync_services_with_prices!(selected_services.map(&:id))
  end
end

future_dates =
  ((Date.current + 1.day)..2.months.from_now.to_date)
    .select { |date| (1..6).cover?(date.wday) }
    .first(20)

future_dates.each_with_index do |appointment_date, index|
  start_time = "10:00"
  end_time = "11:00"

  client = clients[index % clients.size]

  selected_services = [
    services[(index + 3) % services.size]
  ]

  appointment =
    find_appointment.call(appointment_date, start_time) ||
    user.appointments.new

  appointment.assign_attributes(
    client: client,
    appointment_date: appointment_date,
    appointment_time: start_time,
    end_time: end_time
  )

  appointment.notes ||= "Demo future appointment"

  appointment.save!

  appointment.sync_services_with_prices!(selected_services.map(&:id))
end

puts "✅ Appointments seeded"

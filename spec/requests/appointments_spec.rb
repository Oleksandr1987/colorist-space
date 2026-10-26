require "rails_helper"

RSpec.describe "Appointments" do
  include Devise::Test::IntegrationHelpers
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, :trial) }
  let(:client) { create(:client, user: user) }
  let(:service) { create(:service, user: user, service_type: "service") }
  let(:appointment) { create(:appointment, user: user, client: client, main_service: service) }

  before do
    travel_to Time.zone.local(2026, 1, 15)
    sign_in user, scope: :user
  end

  after { travel_back }

  describe "GET /appointments/new" do
    it "renders page" do
      get new_appointment_path

      expect(response).to have_http_status(:ok)
    end

    it "prefills client, time and date" do
      get new_appointment_path, params: { client_id: client.id, time: "12:30", date: Date.current.to_s }

      expect(response).to have_http_status(:ok)
    end

    it "does not allow past date in new action" do
      get new_appointment_path, params: { date: 2.days.ago.to_date.to_s }

      expect(response).to have_http_status(:ok)
    end

    it "handles missing client in new action" do
      get new_appointment_path, params: { client_id: 999999 }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /appointments/all" do
    it "filters by multiple service categories" do
      coloring_service = create(:service, user: user, category: "coloring", subtype: "Coloring service")
      haircut_service = create(:service, user: user, category: "haircut", subtype: "Haircut service")
      treatment_service = create(:service, user: user, category: "treatment", subtype: "Treatment service")

      coloring_appointment = create(:appointment, user: user, appointment_time: "10:00", end_time: "10:30")
      haircut_appointment = create(:appointment, user: user, appointment_time: "11:00", end_time: "11:30")
      treatment_appointment = create(:appointment, user: user, appointment_time: "12:00", end_time: "12:30")

      coloring_appointment.sync_services_with_prices!([ coloring_service.id ])
      haircut_appointment.sync_services_with_prices!([ haircut_service.id ])
      treatment_appointment.sync_services_with_prices!([ treatment_service.id ])

      get all_appointments_path, params: { categories: [ "coloring", "haircut" ] }

      expect(response).to have_http_status(:ok)

      expect(response.body).to include(edit_appointment_path(coloring_appointment, locale: I18n.locale))
      expect(response.body).to include(edit_appointment_path(haircut_appointment, locale: I18n.locale))
      expect(response.body).not_to include(edit_appointment_path(treatment_appointment, locale: I18n.locale))
    end

    it "filters by multiple services" do
      first_service = create(:service, user: user, subtype: "First selected service")
      second_service = create(:service, user: user, subtype: "Second selected service")
      excluded_service = create(:service, user: user, subtype: "Excluded service")

      first_appointment = create(:appointment, user: user, appointment_time: "10:00", end_time: "10:30")
      second_appointment = create(:appointment, user: user, appointment_time: "11:00", end_time: "11:30")
      excluded_appointment = create(:appointment, user: user, appointment_time: "12:00", end_time: "12:30")
      first_appointment.sync_services_with_prices!([ first_service.id ])
      second_appointment.sync_services_with_prices!([ second_service.id ])
      excluded_appointment.sync_services_with_prices!([ excluded_service.id ])

      get all_appointments_path, params: { service_ids: [ first_service.id, second_service.id ] }

      expect(response).to have_http_status(:ok)

      expect(response.body).to include(edit_appointment_path(first_appointment, locale: I18n.locale))
      expect(response.body).to include(edit_appointment_path(second_appointment, locale: I18n.locale))
      expect(response.body).not_to include(edit_appointment_path(excluded_appointment, locale: I18n.locale))
    end
  end

  describe "GET /appointments/calendar" do
    it "returns success" do
      create(:appointment, user: user, client: client, appointment_date: Date.current, main_service: service)

      get calendar_appointments_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /appointments/by_date" do
    it "returns json appointments" do
      appointment = create(:appointment, user: user, client: client, appointment_date: Date.current, main_service: service)

      get by_date_appointments_path, params: { date: Date.current }

      json = JSON.parse(response.body)

      expect(json.first["id"]).to eq(appointment.id)
    end

    it "uses today when date missing" do
      get by_date_appointments_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /appointments/check_working_hours" do
    let(:date) { Date.new(2026, 1, 19) }
    let(:path) { check_working_hours_appointments_path }
    let(:json) { response.parsed_body }

    context "when the date is a working day" do
      before do
        create(:slot_rule, user: user, weekdays: %w[monday], start_time: "09:00", end_time: "18:00")
      end

      it "returns working intervals when times are missing" do
        get path, params: { date: date.iso8601 }

        expect(response).to have_http_status(:ok)
        expect(json).to eq("status" => "ok", "intervals" => [ { "start" => "09:00", "end" => "18:00" } ])
      end

      it "returns ok when appointment is within working hours" do
        get path, params: { date: date.iso8601, start_time: "10:00", end_time: "11:00" }

        expect(response).to have_http_status(:ok)
        expect(json["status"]).to eq("ok")
      end

      it "returns outside_hours when appointment starts before working hours" do
        get path, params: { date: date.iso8601, start_time: "08:00", end_time: "10:00" }

        expect(response).to have_http_status(:ok)
        expect(json["status"]).to eq("outside_hours")
        expect(json["intervals"]).to eq([ { "start" => "09:00", "end" => "18:00" } ])
      end

      it "returns outside_hours when appointment ends after working hours" do
        get path, params: { date: date.iso8601, start_time: "17:00", end_time: "19:00" }

        expect(response).to have_http_status(:ok)
        expect(json["status"]).to eq("outside_hours")
      end

      it "returns invalid_time when end time equals start time" do
        get path, params: { date: date.iso8601, start_time: "10:00", end_time: "10:00" }

        expect(response).to have_http_status(:ok)
        expect(json).to eq("status" => "invalid_time")
      end

      it "returns invalid_time when end time is earlier than start time" do
        get path, params: { date: date.iso8601, start_time: "12:00", end_time: "11:00" }

        expect(response).to have_http_status(:ok)
        expect(json).to eq("status" => "invalid_time")
      end
    end

    context "when the date is a day off" do
      before do
        create(:slot_rule, user: user, weekdays: %w[tuesday], start_time: "09:00", end_time: "18:00")
      end

      it "returns day_off" do
        get path, params: { date: date.iso8601 }

        expect(response).to have_http_status(:ok)
        expect(json).to eq("status" => "day_off")
      end
    end

    context "when the user has no slot rules" do
      it "returns day_off" do
        get path, params: { date: date.iso8601 }

        expect(response).to have_http_status(:ok)
        expect(json).to eq("status" => "day_off")
      end
    end

    context "when slot rules belong to another user" do
      before do
        create(:slot_rule, weekdays: %w[monday], start_time: "09:00", end_time: "18:00")
      end

      it "does not expose another user's working hours" do
        get path, params: { date: date.iso8601 }

        expect(response).to have_http_status(:ok)
        expect(json).to eq("status" => "day_off")
      end
    end

    context "when working intervals have a gap" do
      before do
        create(:slot_rule, user: user, weekdays: %w[monday], start_time: "09:00", end_time: "12:00")
        create(:slot_rule, user: user, weekdays: %w[monday], start_time: "13:00", end_time: "18:00")
      end

      it "returns separate intervals" do
        get path, params: { date: date.iso8601 }

        expect(response).to have_http_status(:ok)
        expect(json["intervals"]).to eq([
          { "start" => "09:00", "end" => "12:00" },
          { "start" => "13:00", "end" => "18:00" }
        ])
      end

      it "returns outside_hours when appointment crosses the gap" do
        get path, params: { date: date.iso8601, start_time: "11:00", end_time: "14:00" }

        expect(response).to have_http_status(:ok)
        expect(json["status"]).to eq("outside_hours")
      end
    end

    context "when date is invalid" do
      it "returns unprocessable_content for an invalid date" do
        get path, params: { date: "invalid-date" }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json).to eq("status" => "invalid_date")
      end

      it "returns unprocessable_content when date is missing" do
        get path

        expect(response).to have_http_status(:unprocessable_content)
        expect(json).to eq("status" => "invalid_date")
      end

      it "returns unprocessable_content for a nonexistent date" do
        get path, params: { date: "2026-02-30" }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json).to eq("status" => "invalid_date")
      end
    end

    context "when passing parameters to the service" do
      it "passes the authenticated user, date and times" do
        checker = instance_double(Appointments::WorkingHoursCheck, call: { status: "ok", intervals: [] })

        allow(Appointments::WorkingHoursCheck).to receive(:new).and_return(checker)

        get path, params: { date: date.iso8601, start_time: "10:00", end_time: "11:00" }

        expect(Appointments::WorkingHoursCheck).to have_received(:new).with(
          user: user, date: date, start_time: "10:00", end_time: "11:00"
        )
        expect(checker).to have_received(:call)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /appointments/free_slots" do
    it "returns json slots" do
      allow(Appointment).to receive(:available_time_ranges).and_return([
        { start: Time.zone.parse("10:00"), end: Time.zone.parse("10:30") }
      ])

      get free_slots_appointments_path, params: { date: Date.current }

      json = JSON.parse(response.body)

      expect(json.first["start"]).to be_present
      expect(json.first["end"]).to be_present
    end

    it "returns empty array for past date" do
      get free_slots_appointments_path, params: { date: 1.day.ago.to_date }

      expect(JSON.parse(response.body)).to eq([])
    end
  end

  describe "POST /appointments" do
    let(:params) do
      { appointment: {
          appointment_date: Date.current + 1.day,
          appointment_time: "10:00",
          service_ids: [ service.id ],
          client_name: client.full_name,
          phone: client.phone
        }
      }
    end

    it "creates appointment" do
      expect { post appointments_path, params: params }.to change(user.appointments, :count).by(1)

      expect(response).to redirect_to(appointment_url(Appointment.last, locale: I18n.locale))
    end

    it "sets default end_time when missing during create" do
      expect { post appointments_path, params: params }.to change(user.appointments, :count).by(1)

      created_appointment = user.appointments.order(:id).last

      expect(created_appointment.appointment_time.strftime("%H:%M")).to eq("10:00")
      expect(created_appointment.end_time.strftime("%H:%M")).to eq("10:30")
      expect(response).to redirect_to(appointment_url(created_appointment, locale: I18n.locale))
    end

    it "returns bad request when appointment params missing" do
      post appointments_path, params: {}

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "POST /appointments invalid" do
    it "renders new when invalid" do
      post appointments_path, params: {
        appointment: { appointment_date: "", appointment_time: "", client_name: "", phone: "" }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /appointments/:id" do
    before { appointment }

    it "updates appointment notes" do
      patch appointment_path(appointment), params: {
        appointment: { notes: "Updated", service_ids: [ service.id ], client_name: client.full_name, phone: client.phone }
      }

      expect(response).to redirect_to(appointment_url(appointment, locale: I18n.locale))
      expect(appointment.reload.notes).to eq("Updated")
    end

    it "updates appointment without changing services" do
      old_services = appointment.services.to_a

      patch appointment_path(appointment), params: {
        appointment: { notes: "Only notes updated", client_name: client.full_name, phone: client.phone }
      }

      expect(response).to redirect_to(appointment_url(appointment, locale: I18n.locale))
      expect(appointment.reload.services).to match_array(old_services)
    end

    it "renders edit when update invalid" do
      patch appointment_path(appointment), params: {
        appointment: { appointment_date: "", client_name: "", phone: "" }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "keeps the existing client when the name matches but the phone is different" do
      appointment
      existing_phone = client.phone

      expect {
        patch appointment_path(appointment), params: { appointment: { client_name: client.full_name, phone: "+380930000099" } }
      }.not_to change(Client, :count)

      expect(response).to redirect_to(appointment_url(appointment, locale: I18n.locale))
      expect(appointment.reload.client).to eq(client)
      expect(client.reload.phone).to eq(existing_phone)
    end

    it "removes all services when service_ids contains only a blank value" do
      expect(appointment.services).to contain_exactly(service)

      patch appointment_path(appointment), params: {
        appointment: { client_name: client.full_name, phone: client.phone, service_ids: [ "" ] }
      }

      expect(response).to redirect_to(appointment_url(appointment, locale: I18n.locale))

      appointment.reload

      expect(appointment.services).to be_empty
      expect(appointment.appointment_services_relations).to be_empty
      expect(appointment.service_name).to be_blank
    end
  end

  describe "DELETE /appointments/:id" do
    before { appointment }

    it "destroys appointment" do
      expect { delete appointment_path(appointment) }.to change(Appointment, :count).by(-1)
    end

    it "does not fail without appointment params" do
      delete appointment_path(appointment)

      expect(response).to redirect_to(calendar_appointments_path(locale: I18n.locale))
    end
  end
end

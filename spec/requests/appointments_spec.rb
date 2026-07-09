require "rails_helper"

RSpec.describe "Appointments" do
  include Devise::Test::IntegrationHelpers
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, :trial) }
  let(:client) { create(:client, user: user) }
  let(:service) { create(:service, user: user, service_type: "service") }

  before do
    travel_to Time.zone.local(2026, 1, 15)
    sign_in user, scope: :user
  end

  after { travel_back }

  describe "GET /appointments" do
    it "returns success" do
      create(
        :appointment,
        user: user,
        client: client,
        appointment_date: Date.current + 1.day,
        main_service: service
      )

      get appointments_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /appointments/history" do
    it "returns success" do
      appointment = create(
        :appointment,
        user: user,
        client: client,
        main_service: service
      )

      appointment.update_column(:appointment_date, Date.current - 1.day)

      get history_appointments_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /appointments/new" do
    it "renders page" do
      get new_appointment_path
      expect(response).to have_http_status(:ok)
    end

    it "prefills client, time and date" do
      get new_appointment_path, params: {
        client_id: client.id,
        time: "12:30",
        date: Date.current.to_s
      }

      expect(response).to have_http_status(:ok)
    end

    it "does not allow past date in new action" do
      get new_appointment_path, params: {
        date: 2.days.ago.to_date.to_s
      }

      expect(response).to have_http_status(:ok)
    end

    it "handles missing client in new action" do
      get new_appointment_path, params: {
        client_id: 999999
      }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /appointments" do
    it "creates appointment" do
      params = {
        appointment: {
          appointment_date: Date.current + 1.day,
          appointment_time: "10:00",
          service_ids: [ service.id ],
          client_name: client.full_name,
          phone: client.phone
        }
      }

      expect {
        post appointments_path, params: params
      }.to change(user.appointments, :count).by(1)

      expect(response).to redirect_to(appointment_url(Appointment.last, locale: I18n.locale))
    end

    it "handles missing end_time during create" do
      post appointments_path, params: {
        appointment: {
          appointment_date: Date.current + 1.day,
          appointment_time: "10:00",
          client_name: client.full_name,
          phone: client.phone,
          service_ids: [ service.id ]
        }
      }

      expect(response).to redirect_to(
        appointment_url(Appointment.last, locale: I18n.locale)
      )
    end

    it "returns bad request when appointment params missing" do
      post appointments_path, params: {}

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "POST /appointments invalid" do
    it "renders new when invalid" do
      post appointments_path, params: {
        appointment: {
          appointment_date: "",
          appointment_time: "",
          client_name: "",
          phone: ""
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /appointments/:id" do
    it "updates appointment notes" do
      appointment = create(
        :appointment,
        user: user,
        client: client,
        main_service: service
      )

      patch appointment_path(appointment), params: {
        appointment: {
          notes: "Updated",
          service_ids: [ service.id ],
          client_name: client.full_name,
          phone: client.phone
        }
      }

      expect(response).to redirect_to(appointment_url(appointment, locale: I18n.locale))
      expect(appointment.reload.notes).to eq("Updated")
    end

    it "updates appointment without changing services" do
      appointment = create(
        :appointment,
        user: user,
        client: client,
        main_service: service
      )

      old_services = appointment.services.to_a

      patch appointment_path(appointment), params: {
        appointment: {
          notes: "Only notes updated",
          client_name: client.full_name,
          phone: client.phone
        }
      }

      expect(response).to redirect_to(
        appointment_url(appointment, locale: I18n.locale)
      )

      expect(appointment.reload.services).to match_array(old_services)
    end

    it "renders edit when update invalid" do
      appointment = create(
        :appointment,
        user: user,
        client: client,
        main_service: service
      )

      patch appointment_path(appointment), params: {
        appointment: {
          appointment_date: "",
          client_name: "",
          phone: ""
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /appointments/:id" do
    it "destroys appointment" do
      appointment = create(
        :appointment,
        user: user,
        client: client,
        main_service: service
      )

      expect {
        delete appointment_path(appointment)
      }.to change(Appointment, :count).by(-1)
    end

    it "does not fail without appointment params" do
      appointment = create(
        :appointment,
        user: user,
        client: client,
        main_service: service
      )

      delete appointment_path(appointment)

      expect(response).to redirect_to(
        appointments_url(locale: I18n.locale)
      )
    end
  end

  describe "GET /appointments/calendar" do
    it "returns success" do
      create(
        :appointment,
        user: user,
        client: client,
        appointment_date: Date.current,
        main_service: service
      )

      get calendar_appointments_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /appointments/by_date" do
    it "returns json appointments" do
      appointment = create(
        :appointment,
        user: user,
        client: client,
        appointment_date: Date.current,
        main_service: service
      )

      get by_date_appointments_path, params: { date: Date.current }

      json = JSON.parse(response.body)

      expect(json.first["id"]).to eq(appointment.id)
    end

    it "uses today when date missing" do
      get by_date_appointments_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /appointments/free_slots" do
    it "returns json slots" do
      allow(Appointment).to receive(:available_slots).and_return([
        { start: Time.zone.parse("10:00"), end: Time.zone.parse("10:30") }
      ])

      get free_slots_appointments_path, params: { date: Date.current }

      json = JSON.parse(response.body)

      expect(json.first["start"]).to be_present
      expect(json.first["end"]).to be_present
    end

    it "returns empty array for past date" do
      get free_slots_appointments_path, params: {
        date: 1.day.ago.to_date
      }

      expect(JSON.parse(response.body)).to eq([])
    end
  end
end

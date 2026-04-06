require "rails_helper"

RSpec.describe "Appointments", type: :request do
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
  end
end

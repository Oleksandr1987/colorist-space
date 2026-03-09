# require "rails_helper"

# RSpec.describe AppointmentsController, type: :controller do
#   include ActiveSupport::Testing::TimeHelpers

#   let(:user) { create(:user) }
#   let(:client) { create(:client, user: user) }
#   let(:main_service) { create(:service, user: user) }

#   before do
#     travel_to Time.zone.local(2026, 1, 15)

#     request.env["devise.mapping"] = Devise.mappings[:user]
#     allow(request.env["warden"]).to receive(:authenticate!).and_return(user)
#     allow(controller).to receive(:current_user).and_return(user)
#   end

#   after do
#     travel_back
#   end

#   describe "GET #index" do
#     it "assigns future appointments grouped by month" do
#       appointment = create(
#         :appointment,
#         user: user,
#         client: client,
#         appointment_date: Date.current + 1.day,
#         main_service: main_service
#       )

#       get :index

#       expect(assigns(:future_appointments)).to include(appointment)
#       expect(assigns(:appointments_by_month)).to be_present
#     end
#   end

#   describe "GET #history" do
#     it "assigns past appointments grouped by month" do
#       appointment = create(
#         :appointment,
#         user: user,
#         client: client,
#         appointment_date: Date.current - 1.day,
#         main_service: main_service
#       )

#       get :history

#       expect(assigns(:past_appointments)).to include(appointment)
#       expect(assigns(:appointments_by_month)).to be_present
#     end
#   end

#   describe "GET #new" do
#     it "builds a new appointment" do
#       get :new

#       expect(assigns(:appointment)).to be_a_new(Appointment)
#     end

#     it "pre-fills client if client_id provided" do
#       get :new, params: { client_id: client.id }

#       expect(assigns(:appointment).client).to eq(client)
#     end

#     it "pre-fills date and time" do
#       get :new, params: { date: "2026-01-20", time: "10:00" }

#       expect(assigns(:appointment).appointment_date.to_s).to eq("2026-01-20")
#       expect(assigns(:appointment).appointment_time).to eq("10:00")
#     end
#   end

#   describe "POST #create" do
#     it "creates appointment and redirects" do
#       expect {
#         post :create, params: {
#           appointment: {
#             appointment_date: Date.current + 1.day,
#             appointment_time: "10:00",
#             service_ids: [main_service.id],
#             client_name: "John Doe",
#             phone: "123456"
#           }
#         }
#       }.to change(Appointment, :count).by(1)

#       expect(response).to redirect_to(Appointment.last)
#     end

#     it "renders new if invalid" do
#       post :create, params: {
#         appointment: {
#           appointment_date: nil,
#           appointment_time: nil,
#           client_name: "John Doe"
#         }
#       }

#       expect(response).to have_http_status(:unprocessable_entity)
#     end
#   end

#   describe "GET #edit" do
#     it "renders edit page" do
#       appointment = create(
#         :appointment,
#         user: user,
#         client: client,
#         main_service: main_service
#       )

#       get :edit, params: { id: appointment.id }

#       expect(assigns(:appointment)).to eq(appointment)
#     end
#   end

#   describe "PATCH #update" do
#     it "updates appointment" do
#       appointment = create(
#         :appointment,
#         user: user,
#         client: client,
#         main_service: main_service
#       )

#       patch :update, params: {
#         id: appointment.id,
#         appointment: {
#           notes: "Updated note",
#           service_ids: [main_service.id],
#           client_name: "John Updated",
#           phone: "111"
#         }
#       }

#       appointment.reload

#       expect(appointment.notes).to eq("Updated note")
#       expect(response).to redirect_to(appointment)
#     end
#   end

#   describe "DELETE #destroy" do
#     it "destroys appointment" do
#       appointment = create(
#         :appointment,
#         user: user,
#         client: client,
#         main_service: main_service
#       )

#       expect {
#         delete :destroy, params: { id: appointment.id }
#       }.to change(Appointment, :count).by(-1)

#       expect(response).to redirect_to(appointments_path)
#     end
#   end

#   describe "GET #calendar" do
#     it "renders calendar page" do
#       get :calendar

#       expect(response).to have_http_status(:ok)
#     end
#   end

#   describe "GET #by_date" do
#     it "returns appointments JSON for date" do
#       appointment = create(
#         :appointment,
#         user: user,
#         client: client,
#         appointment_date: Date.current,
#         main_service: main_service
#       )

#       get :by_date, params: { date: Date.current }

#       json = JSON.parse(response.body)

#       expect(json.first["id"]).to eq(appointment.id)
#     end
#   end

#   describe "GET #free_slots" do
#     it "returns available slots JSON" do
#       allow(Appointment).to receive(:available_slots).and_return([
#         { start: Time.zone.parse("10:00"), end: Time.zone.parse("10:30") }
#       ])

#       get :free_slots, params: { date: Date.current }

#       json = JSON.parse(response.body)

#       expect(json.first["start"]).to be_present
#       expect(json.first["end"]).to be_present
#     end
#   end
# end

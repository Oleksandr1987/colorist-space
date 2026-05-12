require "rails_helper"

RSpec.describe "ServiceNotes", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user, :trial) }
  let(:client) { create(:client, user: user) }
  let(:service_note) { create(:service_note, client: client, user: user) }
  let(:appointment) { create(:appointment, user: user, client: client) }

  before do
    sign_in user, scope: :user
  end

  describe "GET /new" do
    it "renders new service note page" do
      get new_client_service_note_path(
        client,
        appointment_id: appointment.id
      )

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /edit" do
    it "renders edit page" do
      get edit_client_service_note_path(client, service_note, locale: I18n.locale)

      expect(response).to have_http_status(:ok)
    end

    it "loads appointment and selected services" do
      service = create(:service, user: user)

      service_note.services << service

      get edit_client_service_note_path(client, service_note, locale: I18n.locale)

      expect(response.body).to include(service.subtype)
    end
  end

  describe "POST /service_notes" do
    it "creates a service note" do
      service = create(:service, user: user)

      expect do
        post client_service_notes_path(client), params: {
          appointment_id: appointment.id,
          service_note: {
            service_type: "coloring",
            notes: "Test",
            service_ids: [ service.id ]
          }
        }
      end.to change(ServiceNote, :count).by(1)

      expect(response).to redirect_to(
        edit_client_service_note_path(
          ServiceNote.last.client,
          ServiceNote.last,
          locale: I18n.locale
        )
      )
    end

    it "creates service note with explicit service_ids" do
      service = create(:service, user: user)

      post client_service_notes_path(client), params: {
        appointment_id: appointment.id,
        service_note: {
          service_type: "coloring",
          notes: "With services",
          service_ids: [ service.id, service.id ]
        }
      }

      expect(ServiceNote.last.service_ids).to eq([ service.id ])
    end

    it "copies services from appointment when service_ids missing" do
      service = create(:service, user: user)

      appointment.services << service

      post client_service_notes_path(client), params: {
        appointment_id: appointment.id,
        service_note: {
          service_type: "coloring",
          notes: "Copied"
        }
      }

      expect(ServiceNote.last.service_ids).to eq([ service.id ])
    end

    it "renders new when services missing" do
      post client_service_notes_path(client), params: {
        appointment_id: appointment.id,
        service_note: {
          service_type: "coloring",
          notes: "Test"
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("service_notes.errors.services_required"))
    end
  end

  describe "PATCH /service_notes/:id" do
    it "updates service note" do
      patch client_service_note_path(client, service_note), params: {
        service_note: { notes: "Updated" }
      }

      expect(service_note.reload.notes).to eq("Updated")
    end

    it "renders edit when services missing" do
      service_note.appointment.services.clear
      service_note.services.clear

      patch client_service_note_path(client, service_note), params: {
        service_note: {
          service_ids: []
        }
      }

      expect(response).to have_http_status(:unprocessable_content)

      expect(response.body).to include(I18n.t("service_notes.errors.services_required"))
    end

    it "updates with unique service_ids" do
      service = create(:service, user: user)

      patch client_service_note_path(client, service_note), params: {
        service_note: {
          service_ids: [ service.id, service.id ]
        }
      }

      expect(service_note.reload.service_ids).to eq([ service.id ])
    end
  end

  describe "DELETE /service_notes/:id" do
    it "destroys service note" do
      service_note

      expect do
        delete client_service_note_path(client, service_note)
      end.to change(ServiceNote, :count).by(-1)
    end
  end

  describe "delete_photo" do
     it "returns ok after deleting photo" do
      service_note.photos.attach(
        io: StringIO.new("fake"),
        filename: "test.jpg",
        content_type: "image/jpeg"
      )

      photo = service_note.photos.first

      delete delete_photo_client_service_note_path(
        client,
        service_note,
        photo_id: photo.id
      )

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /attach_photos" do
    it "returns early when photos missing" do
      service = create(:service, user: user)

      post client_service_notes_path(client), params: {
        service_note: {
          service_type: "coloring",
          notes: "No photos",
          service_ids: [ service.id ]
        },
        appointment_id: appointment.id
      }

      expect(response).to redirect_to(
        edit_client_service_note_path(
          client,
          ServiceNote.last,
          locale: I18n.locale
        )
      )
    end
  end
end

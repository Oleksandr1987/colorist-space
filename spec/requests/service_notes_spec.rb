require "rails_helper"

RSpec.describe "ServiceNotes", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user, :trial) }
  let(:client) { create(:client, user: user) }
  let(:service_note) { create(:service_note, client: client, user: user) }

  before do
    sign_in user
  end

  describe "GET /new" do
    it "renders new service note page" do
      get new_client_service_note_path(client)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /service_notes" do
    it "creates a service note" do
      expect do
        post client_service_notes_path(client), params: {
          service_note: {
            service_type: "coloring",
            notes: "Test",
            price: 100
          }
        }
      end.to change(ServiceNote, :count).by(1)

      expect(response).to redirect_to(
        client_service_note_path(ServiceNote.last.client, ServiceNote.last, locale: I18n.locale)
      )
    end
  end

  describe "PATCH /service_notes/:id" do
    it "updates service note" do
      patch client_service_note_path(client, service_note), params: {
        service_note: { notes: "Updated" }
      }

      expect(service_note.reload.notes).to eq("Updated")
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
end

require "rails_helper"

RSpec.describe "Clients" do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user, :trial) }
  let(:client) { create(:client, user: user) }
  let(:file) { fixture_file_upload(Rails.root.join("spec/fixtures/files/test_image.jpg"), "image/jpeg") }

  before do
    sign_in user, scope: :user
  end

  describe "GET /clients" do
    it "returns success" do
      create(:client, user: user)

      get clients_path

      expect(response).to have_http_status(:ok)
    end

    it "does not return archived clients in the clients list" do
      client.update!(archived_at: Time.current)

      get clients_path

      expect(response.body).not_to include(client.full_name)
    end
  end

  describe "GET /clients/search" do
    it "returns filtered clients" do
      matching_client = create(:client, user: user, first_name: "Alex")
      create(:client, user: user, first_name: "John")

      get search_clients_path, params: { query: "alex" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(matching_client.first_name)
    end
  end

  describe "GET /clients/:id" do
    it "shows client" do
      get client_path(client)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /clients/new" do
    it "renders page" do
      get new_client_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /clients/:id/edit" do
    it "renders edit page" do
      get edit_client_path(client)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /clients/autocomplete" do
    it "returns json clients" do
      matching_client = create(:client, user: user, first_name: "Alex")

      get autocomplete_clients_path, params: { term: "alex" }

      json = JSON.parse(response.body)

      expect(json.first["id"]).to eq(matching_client.id)
      expect(json.first["first_name"]).to eq("Alex")
    end
  end

  describe "POST /clients" do
    it "creates client" do
      params = { client: { first_name: "John", last_name: "Doe", phone: "+380930000999" } }

      expect { post clients_path, params: params }.to change(user.clients, :count).by(1)
      expect(response).to redirect_to(client_url(Client.last, locale: I18n.locale))
    end

    it "renders new when invalid" do
      params = { client: { first_name: "", last_name: "", phone: "" } }

      post clients_path, params: params

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "renders new when client with same phone already exists" do
      existing_client = create(:client, user: user, phone: "+380930000999")

      expect {
        post clients_path, params: { client: { first_name: "New", last_name: "Client", phone: "0930000999" } }
      }.not_to change(user.clients, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("activerecord.errors.models.client.attributes.phone.client_already_exists"))
      expect(existing_client.reload.phone).to eq("+380930000999")
    end
  end

  describe "PATCH /clients/:id" do
    it "updates client" do
      patch client_path(client), params: { client: { first_name: "Updated" } }

      expect(response).to redirect_to(client_url(client, locale: I18n.locale))
      expect(client.reload.first_name).to eq("Updated")
    end

    it "renders edit when update invalid" do
      patch client_path(client), params: { client: { first_name: "", last_name: "", phone: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /clients/:id/make_primary" do
    it "marks phone as primary" do
      allow(client).to receive(:make_primary!).with("+380111111111")

      patch make_primary_client_path(client, format: :turbo_stream), params: { phone: "+380111111111" }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "DELETE /clients/:id" do
    let!(:past_appointment) { create(:appointment, user: user, client: client, appointment_date: 1.day.ago) }
    let!(:future_appointment) { create(:appointment, user: user, client: client, appointment_date: 1.day.from_now) }

    it "archives client, preserves history and removes future appointments" do
      expect {
        delete client_path(client)
      }.not_to change(Client, :count)

      expect(response).to redirect_to(clients_url(locale: I18n.locale))
      expect(client.reload).to be_archived
      expect(Appointment.exists?(past_appointment.id)).to be(true)
      expect(Appointment.exists?(future_appointment.id)).to be(false)
    end
  end

  describe "DELETE /clients/:id/delete_photo" do
    it "removes a photo" do
      client.photos.attach(file)

      photo_id = client.photos.first.id

      delete delete_photo_client_path(client, photo_id: photo_id)

      expect(response).to redirect_to(client_url(client, locale: I18n.locale))
    end
  end

  describe "DELETE /clients/:id/delete_all_photos" do
    it "removes all photos" do
      client.photos.attach(file)

      delete delete_all_photos_client_path(client)

      expect(response).to redirect_to(client_url(client, locale: I18n.locale))
    end
  end
end

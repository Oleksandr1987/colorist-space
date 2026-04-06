require "rails_helper"

RSpec.describe "Clients", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user, :trial) }
  let(:client) { create(:client, user: user) }

  before do
    sign_in user, scope: :user
  end

  describe "GET /clients" do
    it "returns success" do
      create(:client, user: user)

      get clients_path

      expect(response).to have_http_status(:ok)
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

  describe "POST /clients" do
    it "creates client" do
      params = {
        client: {
          first_name: "John",
          last_name: "Doe",
          phone: "+380930000999"
        }
      }

      expect {
        post clients_path, params: params
      }.to change(user.clients, :count).by(1)

      expect(response).to redirect_to(edit_client_url(Client.last, locale: I18n.locale))
    end

    it "renders new when invalid" do
      params = {
        client: {
          first_name: "",
          last_name: "",
          phone: ""
        }
      }

      post clients_path, params: params

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /clients/:id/edit" do
    it "renders edit page" do
      get edit_client_path(client)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /clients/:id" do
    it "updates client" do
      patch client_path(client), params: {
        client: {
          first_name: "Updated"
        }
      }

      expect(response).to redirect_to(client_url(client, locale: I18n.locale))
      expect(client.reload.first_name).to eq("Updated")
    end
  end

  describe "DELETE /clients/:id" do
    it "destroys client" do
      client

      expect {
        delete client_path(client)
      }.to change(Client, :count).by(-1)

      expect(response).to redirect_to(clients_url(locale: I18n.locale))
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

  describe "DELETE /clients/:id/delete_photo" do
    it "removes a photo" do
      file = fixture_file_upload(
        Rails.root.join("spec/fixtures/files/test_image.jpg"),
        "image/jpeg"
      )

      client.photos.attach(file)

      photo_id = client.photos.first.id

      delete delete_photo_client_path(client, photo_id: photo_id)

      expect(response).to redirect_to(client_url(client, locale: I18n.locale))
    end
  end

  describe "DELETE /clients/:id/delete_all_photos" do
    it "removes all photos" do
      file = fixture_file_upload(
        Rails.root.join("spec/fixtures/files/test_image.jpg"),
        "image/jpeg"
      )

      client.photos.attach(file)

      delete delete_all_photos_client_path(client)

      expect(response).to redirect_to(client_url(client, locale: I18n.locale))
    end
  end
end

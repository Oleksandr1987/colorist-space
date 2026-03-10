require "rails_helper"

RSpec.describe Client, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:appointments).dependent(:destroy) }
    it { is_expected.to have_many(:service_notes).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:client) }

    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_presence_of(:last_name) }
  end

  describe ".alphabetical" do
    it "orders clients by first_name case insensitive" do
      user = create(:user)

      client_b = create(:client, user: user, first_name: "Bob")
      client_a = create(:client, user: user, first_name: "alice")

      result = user.clients.alphabetical

      expect(result.first).to eq(client_a)
      expect(result.last).to eq(client_b)
    end
  end

  describe ".search_by_name" do
    it "finds clients by first name" do
      user = create(:user)

      client = create(:client, user: user, first_name: "Alex", last_name: "Smith")
      create(:client, user: user, first_name: "John", last_name: "Doe")

      result = user.clients.search_by_name("alex")

      expect(result).to contain_exactly(client)
    end

    it "finds clients by last name" do
      user = create(:user)

      client = create(:client, user: user, first_name: "Alex", last_name: "Smith")

      result = user.clients.search_by_name("smith")

      expect(result).to contain_exactly(client)
    end

    it "returns empty relation if nothing matches" do
      user = create(:user)

      create(:client, user: user, first_name: "Alex", last_name: "Smith")

      result = user.clients.search_by_name("zzz")

      expect(result).to be_empty
    end
  end

  describe "#full_name" do
    it "returns combined first and last name" do
      client = build(:client, first_name: "John", last_name: "Doe")

      expect(client.full_name).to eq("John Doe")
    end
  end

  describe "#attach_photos" do
    it "attaches photos" do
      client = create(:client)

      file = fixture_file_upload(
        Rails.root.join("spec/fixtures/files/test_image.jpg"),
        "image/jpeg"
      )

      client.attach_photos([file])

      expect(client.photos).to be_attached
    end
  end

  describe "#delete_photo" do
    it "removes a specific photo" do
      client = create(:client)

      file = fixture_file_upload(
        Rails.root.join("spec/fixtures/files/test_image.jpg"),
        "image/jpeg"
      )

      client.photos.attach(file)

      photo_id = client.photos.first.id

      expect {
        client.delete_photo(photo_id)
      }.to change { client.photos.count }.from(1).to(0)
    end
  end

  describe "#delete_all_photos" do
    it "removes all photos" do
      client = create(:client)

      file = fixture_file_upload(
        Rails.root.join("spec/fixtures/files/test_image.jpg"),
        "image/jpeg"
      )

      client.photos.attach(file)

      client.delete_all_photos

      expect(client.photos).not_to be_attached
    end
  end

  describe ".find_or_create_by_full_name" do
    it "returns existing client if found" do
      user = create(:user)

      existing_client = create(
        :client,
        user: user,
        first_name: "Alex",
        last_name: "Smith"
      )

      result = described_class.find_or_create_by_full_name(
        user: user,
        full_name: "Alex Smith",
        phone: "+380930000001"
      )

      expect(result).to eq(existing_client)
    end

    it "creates client if not found" do
      user = create(:user)

      result = described_class.find_or_create_by_full_name(
        user: user,
        full_name: "Alex Smith",
        phone: "+380930000001"
      )

      expect(result).to be_persisted
      expect(result.first_name).to eq("Alex")
      expect(result.last_name).to eq("Smith")
    end

    it "returns nil if first name missing" do
      user = create(:user)

      result = described_class.find_or_create_by_full_name(
        user: user,
        full_name: "",
        phone: "+380930000001"
      )

      expect(result).to be_nil
    end
  end
end

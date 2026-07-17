require "rails_helper"

RSpec.describe Client do
  let(:user) { create(:user) }
  let(:client) { create(:client, user: user) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:appointments).dependent(:destroy) }
    it { is_expected.to have_many(:service_notes).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:client) }

    it { is_expected.to validate_presence_of(:first_name) }

    it "does not allow primary phone that already exists in client_phones" do
      client1 = create(:client, user: user, phone: "+380501112234")
      client1.client_phones.create!(user: user, phone: "+380501112233")
      client2 = build(:client, user: user, phone: "+380501112233")

      expect(client2).not_to be_valid

      expect(
        client2.errors[:phone]
      ).to include("already exists as additional phone")
    end
  end

  describe ".alphabetical" do
    it "orders clients by first_name case insensitive" do
      client_b = create(:client, user: user, first_name: "Bob")
      client_a = create(:client, user: user, first_name: "alice")

      result = user.clients.alphabetical

      expect(result.first).to eq(client_a)
      expect(result.last).to eq(client_b)
    end
  end

  describe ".search_by_name" do
    it "finds clients by first name" do
      client = create(:client, user: user, first_name: "Alex", last_name: "Smith")
      create(:client, user: user, first_name: "John", last_name: "Doe")

      result = user.clients.search_by_name("alex")

      expect(result).to contain_exactly(client)
    end

    it "finds clients by last name" do
      client = create(:client, user: user, first_name: "Alex", last_name: "Smith")

      result = user.clients.search_by_name("smith")

      expect(result).to contain_exactly(client)
    end

    it "returns empty relation if nothing matches" do
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
      client = create(:client, user: user)

      file = fixture_file_upload(
        Rails.root.join("spec/fixtures/files/test_image.jpg"),
        "image/jpeg"
      )

      client.attach_photos([ file ])

      expect(client.photos).to be_attached
    end
  end

  describe "#delete_photo" do
    it "removes a specific photo" do
      client = create(:client, user: user)

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
      client = create(:client, user: user)

      file = fixture_file_upload(
        Rails.root.join("spec/fixtures/files/test_image.jpg"),
        "image/jpeg"
      )

      client.photos.attach(file)

      client.delete_all_photos

      expect(client.photos).not_to be_attached
    end
  end

  describe "#decorated_photos" do
    it "decorates attached photos" do
      client = create(:client, user: user)

      file = fixture_file_upload(
        Rails.root.join("spec/fixtures/files/test_image.jpg"),
        "image/jpeg"
      )

      client.photos.attach(file)

      decorated = instance_double(PhotoDecorator)

      allow(PhotoDecorator)
        .to receive(:decorate)
        .and_return(decorated)

      expect(client.decorated_photos).to eq([ decorated ])
    end

    it "returns empty array when no photos" do
      client = create(:client, user: user)

      expect(client.decorated_photos).to eq([])
    end
  end

  describe ".resolve_for_appointment" do
    it "returns existing client if found" do
      existing_client = create(
        :client,
        user: user,
        first_name: "Alex",
        last_name: "Smith"
      )

      result = described_class.resolve_for_appointment(
        user: user,
        full_name: "Alex Smith",
        phone: "+380930000001"
      )

      expect(result).to eq(existing_client)
    end

    it "creates client if not found" do
      result = described_class.resolve_for_appointment(
        user: user,
        full_name: "Alex Smith",
        phone: "+380930000001"
      )

      expect(result).to be_persisted
      expect(result.first_name).to eq("Alex")
      expect(result.last_name).to eq("Smith")
    end

    it "returns nil if first name missing" do
      result = described_class.resolve_for_appointment(
        user: user,
        full_name: "",
        phone: "+380930000001"
      )

      expect(result).to be_nil
    end
  end

  describe "#make_primary!" do
    it "moves current phone to client_phones and updates primary phone" do
      client = create(:client, user: user, phone: "+380111111111")

      client.client_phones.create!(phone: "+380222222222")

      client.make_primary!("+380222222222")

      expect(client.reload.phone).to eq("+380222222222")

      expect(
        client.client_phones.pluck(:phone)
      ).to include("+380111111111")

      expect(
        client.client_phones.pluck(:phone)
      ).not_to include("+380222222222")
    end
  end

  describe "#ensure_primary_phone" do
    it "sets phone from client_phones when phone blank" do
      client = build(:client, phone: "+380111111111")

      client.phone = nil
      client.client_phones.build(phone: "+380999999999")

      client.send(:ensure_primary_phone)

      expect(client.phone).to eq("+380999999999")
    end

    it "does nothing when phone present" do
      client = build(:client, phone: "+380111111111")

      client.client_phones.build(phone: "+380222222222")

      client.send(:ensure_primary_phone)

      expect(client.phone).to eq("+380111111111")
    end

    it "does nothing when no client_phones" do
      client = build(:client, phone: nil)

      client.send(:ensure_primary_phone)

      expect(client.phone).to be_nil
    end
  end
end

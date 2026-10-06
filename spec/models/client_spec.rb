require "rails_helper"

RSpec.describe Client do
  let(:user) { create(:user) }
  let(:client) { create(:client, user: user) }
  let(:file) { fixture_file_upload(Rails.root.join("spec/fixtures/files/test_image.jpg"), "image/jpeg") }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:appointments).dependent(:destroy) }
    it { is_expected.to have_many(:service_notes).dependent(:destroy) }
  end

  describe "validations" do
    subject(:client_record) { build(:client) }

    it { is_expected.to validate_presence_of(:first_name) }

    describe "phone uniqueness" do
      let(:primary_phone) { "+380501112234" }
      let(:additional_phone) { "+380501112233" }

      it "does not allow primary phone that already exists in client_phones" do
        existing_client = create(:client, user: user, phone: primary_phone)
        existing_client.client_phones.create!(user: user, phone: additional_phone)
        duplicate = build(:client, user: user, phone: additional_phone)

        expect(duplicate).not_to be_valid

        expect(duplicate.errors.details[:phone]).to include(error: :client_already_exists)
      end
    end
  end

  describe "#archive!" do
    let!(:past_appointment) { create(:appointment, user: user, client: client, appointment_date: 1.day.ago) }
    let!(:future_appointment) { create(:appointment, user: user, client: client, appointment_date: 1.day.from_now) }

    it "archives the client" do
      expect { client.archive! }.to change { client.reload.archived_at }.from(nil)
    end

    it "keeps past appointments" do
      client.archive!

      expect(Appointment.exists?(past_appointment.id)).to be(true)
    end

    it "destroys future appointments" do
      client.archive!

      expect(Appointment.exists?(future_appointment.id)).to be(false)
    end
  end

  describe ".alphabetical" do
    let!(:client_b) { create(:client, user: user, first_name: "Bob") }
    let!(:client_a) { create(:client, user: user, first_name: "alice") }

    it "orders clients by first_name case insensitive" do
      expect(user.clients.alphabetical).to eq([ client_a, client_b ])
    end
  end

  describe ".search_by_name" do
    let!(:alex)  { create(:client, user: user, first_name: "Alex", last_name: "Smith") }

    it "finds clients by first name" do
      create(:client, user: user, first_name: "John", last_name: "Doe")

      expect(user.clients.search_by_name("alex")).to contain_exactly(alex)
    end

    it "finds clients by last name" do
      expect(user.clients.search_by_name("smith")).to contain_exactly(alex)
    end

    it "returns empty relation if nothing matches" do
      expect(user.clients.search_by_name("zzz")).to be_empty
    end
  end

  describe "#full_name" do
    subject(:client_record) { build(:client, first_name: "John", last_name: "Doe") }

    it "returns combined first and last name" do
      expect(client_record.full_name).to eq("John Doe")
    end
  end

  describe "#attach_photos" do
    it "attaches photos" do
      client.attach_photos([ file ])

      expect(client.photos).to be_attached
    end

    it "does nothing when no files are given" do
      client.attach_photos(nil)

      expect(client.photos).not_to be_attached
    end
  end

  describe "#delete_photo" do
    before do
      client.photos.attach(file)
    end

    it "removes a specific photo" do
      photo_id = client.photos.first.id

      expect {
        client.delete_photo(photo_id)
      }.to change { client.photos.count }.from(1).to(0)
    end
  end

  describe "#delete_all_photos" do
    before do
      client.photos.attach(file)
    end

    it "removes all photos" do
      client.delete_all_photos

      expect(client.photos).not_to be_attached
    end
  end

  describe "#decorated_photos" do
    it "decorates attached photos" do
      client.photos.attach(file)

      decorated = instance_double(PhotoDecorator)

      allow(PhotoDecorator).to receive(:decorate).and_return(decorated)

      expect(client.decorated_photos).to eq([ decorated ])
    end

    it "returns empty array when no photos" do
      expect(client.decorated_photos).to eq([])
    end
  end

  describe ".resolve_for_appointment" do
    subject(:result) { described_class.resolve_for_appointment(user: user, full_name: full_name, phone: phone) }

    let(:first_name) { "Alex" }
    let(:last_name) { "Smith" }
    let(:full_name) { "#{first_name} #{last_name}" }
    let(:primary_phone) { "+380930000011" }
    let(:other_phone) { "+380930000099" }
    let(:phone) { other_phone }
    let(:existing_client) { create(:client, user: user, first_name: first_name, last_name: last_name, phone: primary_phone) }

    context "when client exists with the primary phone" do
      let(:full_name) { "Someone Else" }
      let(:phone) { primary_phone }

      before { existing_client }

      it "returns the existing client" do
        expect(result).to eq(existing_client)
      end
    end

    context "when client does not exist" do
      let(:phone) { "+380930000001" }

      it "creates a new client" do
        expect(result).to be_persisted
        expect(result.first_name).to eq(first_name)
        expect(result.last_name).to eq(last_name)
        expect(result.phone).to eq(phone)
      end
    end

    context "when first name is missing" do
      let(:full_name) { "" }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "when the name matches but the phone is different" do
      before { existing_client }

      it "returns the existing client without creating another one" do
        expect { result }.not_to change(described_class, :count)

        expect(result).to eq(existing_client)
        expect(existing_client.reload.phone).to eq(primary_phone)
      end
    end

    context "when an additional phone matches" do
      let(:full_name) { "Someone Else" }

      before { existing_client.client_phones.create!(user: user, phone: other_phone) }

      it "returns the existing client" do
        expect(result).to eq(existing_client)
      end
    end

    context "when the name matches case insensitively" do
      let(:full_name) { "alex smith" }

      before { existing_client }

      it "returns the existing client" do
        expect(result).to eq(existing_client)
      end
    end

    context "when an archived client matches the primary phone" do
      let(:full_name) { "Someone Else" }
      let(:phone) { primary_phone }

      before do
        existing_client.update!(archived_at: 1.day.ago)
      end

      it "restores and returns the existing client" do
        expect { result }.not_to change(described_class, :count)

        expect(result).to eq(existing_client)
        expect(existing_client.reload).not_to be_archived
      end
    end

    context "when the matching client is archived" do
      before do
        existing_client.update!(archived_at: 1.day.ago)
      end

      it "restores and returns the existing client" do
        expect { result }.not_to change(described_class, :count)

        expect(result).to eq(existing_client)
        expect(existing_client.reload).not_to be_archived
      end
    end
  end

  describe "#style_appointments" do
    let(:service) { create(:service, user: user) }
    let!(:appointment) { create(:appointment, user: user, client: client, main_service: service) }

    it "returns the client's appointments through the for_styles scope" do
      expect(client.style_appointments).to contain_exactly(appointment)
    end
  end

  describe "#birthday_must_be_valid" do
    subject(:client_record) { build(:client, user: user, birthday: birthday) }

    context "when birthday is blank" do
      let(:birthday) { nil }

      it "is valid" do
        expect(client_record).to be_valid
      end
    end

    context "when birthday is valid" do
      let(:birthday) { "05-15" }

      it "is valid" do
        expect(client_record).to be_valid
      end
    end

    context "when birthday is not a real calendar date" do
      let(:birthday) { "02-30" }

      it "is invalid" do
        expect(client_record).not_to be_valid
        expect(client_record.errors[:birthday]).to be_present
      end
    end

    context "when birthday is malformed" do
      let(:birthday) { "13" }

      it "is invalid without raising an error" do
        expect { client_record.valid? }.not_to raise_error
        expect(client_record).not_to be_valid
        expect(client_record.errors[:birthday]).to be_present
      end
    end
  end

  describe "#make_primary!" do
    let(:primary_phone) { "+380111111111" }
    let(:additional_phone) { "+380222222222" }
    let(:client) { create(:client, user: user, phone: primary_phone) }

    before do
      client.client_phones.create!(phone: additional_phone)
    end

    it "moves current phone to client_phones and updates primary phone" do
      client.make_primary!(additional_phone)

      expect(client.reload.phone).to eq(additional_phone)
      expect(client.client_phones.pluck(:phone)).to include(primary_phone)
      expect(client.client_phones.pluck(:phone)).not_to include(additional_phone)
    end
  end

  describe "#ensure_primary_phone" do
    let(:primary_phone) { "+380111111111" }
    let(:additional_phone) { "+380999999999" }

    it "sets phone from client_phones when phone blank" do
      client = build(:client, phone: primary_phone)

      client.phone = nil
      client.client_phones.build(phone: additional_phone)
      client.send(:ensure_primary_phone)

      expect(client.phone).to eq(additional_phone)
    end

    it "does nothing when phone present" do
      client = build(:client, phone: primary_phone)

      client.client_phones.build(phone: additional_phone)
      client.send(:ensure_primary_phone)

      expect(client.phone).to eq(primary_phone)
    end

    it "does nothing when no client_phones" do
      client = build(:client, phone: nil)

      client.send(:ensure_primary_phone)

      expect(client.phone).to be_nil
    end
  end

  describe ".with_name" do
    let!(:client) { create(:client, user: user, first_name: "Alex", last_name: "Smith") }

    it "finds client case insensitively" do
      expect(user.clients.with_name("alex", "smith")).to contain_exactly(client)
    end

    it "finds client ignoring surrounding spaces" do
      expect(user.clients.with_name(" Alex ", " Smith ")).to contain_exactly(client)
    end

    it "does not return client with a different name" do
      expect(user.clients.with_name("John", "Smith")).to be_empty
    end
  end
end

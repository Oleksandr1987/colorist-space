require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:clients).dependent(:destroy) }
    it { is_expected.to have_many(:appointments).dependent(:destroy) }
    it { is_expected.to have_many(:slot_rules).dependent(:destroy) }
    it { is_expected.to have_many(:services).dependent(:destroy) }
    it { is_expected.to have_many(:expenses).dependent(:destroy) }
  end

  describe "validations" do
    subject(:user) { FactoryBot.create(:user) }

    it "is valid with valid attributes" do
      expect(user).to be_valid
    end

    context "when tos_agreement is false" do
      subject(:user) { FactoryBot.build(:user, tos_agreement: false) }

      it "is invalid on create" do
        expect(user).not_to be_valid
      end
    end
  end

  describe ".find_for_database_authentication" do
    let!(:user) do
      FactoryBot.create(
        :user,
        email: "test@example.com",
        phone: "+380501234567"
      )
    end

    it "finds user by email (case insensitive)" do
      result = described_class.find_for_database_authentication(
        login: "TEST@EXAMPLE.COM"
      )

      expect(result).to eq(user)
    end

    it "finds user by normalized phone" do
      allow(PhoneValidator).to receive(:normalize).and_return("+380501234567")

      result = described_class.find_for_database_authentication(
        login: "0501234567"
      )

      expect(result).to eq(user)
    end
  end

  describe ".from_omniauth" do
    let(:auth) do
      OmniAuth::AuthHash.new(
        provider: "google_oauth2",
        uid: "123456",
        info: {
          email: "oauth@example.com",
          name: "OAuth User",
          phone: "+380991112233"
        }
      )
    end

    context "when user with email exists" do
      let!(:existing_user) do
        FactoryBot.create(:user, email: "oauth@example.com", tos_agreement: true)
      end

      it "returns existing user" do
        user = described_class.from_omniauth(auth)
        expect(user).to eq(existing_user)
      end

      it "updates provider and uid" do
        user = described_class.from_omniauth(auth)

        expect(user.provider).to eq("google_oauth2")
        expect(user.uid).to eq("123456")
      end
    end

    context "when user does not exist" do
      subject(:user) { described_class.from_omniauth(auth) }

      it "creates and persists a new user" do
        expect(user).to be_persisted
      end

      it "sets email and provider data" do
        expect(user.email).to eq("oauth@example.com")
        expect(user.provider).to eq("google_oauth2")
        expect(user.uid).to eq("123456")
      end

      it "implicitly accepts terms of service" do
        expect(user.tos_agreement).to be(true)
      end
    end
  end

  describe "#has_active_subscription?" do
    subject(:user) { FactoryBot.create(:user, :with_active_subscription) }

    it "returns true" do
      expect(user.has_active_subscription?).to be(true)
    end

    context "when subscription is expired" do
      subject(:user) { FactoryBot.create(:user, :expired_subscription) }

      it "returns false" do
        expect(user.has_active_subscription?).to be(false)
      end
    end
  end

  describe "#subscription_will_expire_soon?" do
    subject(:user) do
      FactoryBot.create(
        :user,
        subscription_expires_at: 2.days.from_now.to_date
      )
    end

    it "returns true" do
      expect(user.subscription_will_expire_soon?).to be(true)
    end
  end

  describe "#on_trial?" do
    subject(:user) { FactoryBot.create(:user, :trial) }

    it "returns true for trial user" do
      expect(user.on_trial?).to be(true)
    end
  end

  describe "#trial_days_left" do
    subject(:user) do
      FactoryBot.create(:user, created_at: 2.days.ago)
    end

    it "returns remaining trial days" do
      expect(user.trial_days_left).to eq(5)
    end

    context "when trial already expired" do
      subject(:user) do
        FactoryBot.create(:user, created_at: 20.days.ago)
      end

      it "returns 0" do
        expect(user.trial_days_left).to eq(0)
      end
    end
  end

  describe "#has_write_access?" do
    context "with active subscription" do
      subject(:user) { FactoryBot.create(:user, :with_active_subscription) }

      it "returns true" do
        expect(user.has_write_access?).to be(true)
      end
    end

    context "on trial" do
      subject(:user) { FactoryBot.create(:user, :trial) }

      it "returns true" do
        expect(user.has_write_access?).to be(true)
      end
    end
  end

  describe "#superadmin?" do
    context "when role is superadmin" do
      subject(:user) { FactoryBot.create(:user, :superadmin) }

      it "returns true" do
        expect(user.superadmin?).to be(true)
      end
    end

    context "when role is not superadmin" do
      subject(:user) { FactoryBot.create(:user) }

      it "returns false" do
        expect(user.superadmin?).to be(false)
      end
    end
  end
end

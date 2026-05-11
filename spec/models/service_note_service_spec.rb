require "rails_helper"

RSpec.describe ServiceNoteService, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:service_note) }
    it { is_expected.to belong_to(:service) }
  end

  describe "factory" do
    it "is valid" do
      expect(build(:service_note_service)).to be_valid
    end
  end
end

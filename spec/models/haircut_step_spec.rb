require 'rails_helper'

RSpec.describe HaircutStep do
  describe "associations" do
    it { is_expected.to belong_to(:service_note) }
  end

  describe "validations" do
    subject { build(:haircut_step) }

    it { is_expected.to validate_presence_of(:zone) }
  end
end

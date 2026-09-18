require "rails_helper"

RSpec.describe ClientDecorator do
  describe "#formatted_birthday" do
    subject(:formatted_birthday) { client.decorate.formatted_birthday }

    let(:client) { build(:client, birthday: birthday) }

    context "when birthday is February 29" do
      let(:birthday) { "02-29" }

      it "formats the birthday without raising an error" do
        expect { formatted_birthday }.not_to raise_error
      end

      it "formats the leap-day birthday" do
        expected = I18n.l(Date.new(2000, 2, 29), format: :birthday)

        expect(formatted_birthday).to eq(expected)
      end
    end

    context "when birthday is blank" do
      let(:birthday) { nil }

      it "returns nil" do
        expect(formatted_birthday).to be_nil
      end
    end
  end
end

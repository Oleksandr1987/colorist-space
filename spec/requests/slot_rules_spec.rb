# spec/requests/slot_rules_spec.rb

require "rails_helper"

RSpec.describe "SlotRules", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user, :trial) }

  let(:slot_rule) do
    create(
      :slot_rule,
      user: user
    )
  end

  let(:valid_params) do
    {
      slot_rule: {
        start_time: "09:00",
        end_time: "10:00",
        weekdays: %w[monday friday]
      }
    }
  end

  let(:invalid_params) do
    {
      slot_rule: {
        start_time: "",
        end_time: "",
        weekdays: []
      }
    }
  end

  before do
    sign_in user, scope: :user
  end

  describe "GET /index" do
    it "renders index page" do
      slot_rule

      get slot_rules_path

      expect(response).to have_http_status(:ok)
    end

    it "assigns current user slot rules only" do
      own_rule = create(:slot_rule, user: user)

      other_user = create(:user)
      create(:slot_rule, user: other_user)

      get slot_rules_path

      expect(response.body).to include(
        own_rule.start_time.strftime("%H:%M")
      )
    end
  end

  describe "POST /create" do
    it "creates slot rule" do
      expect do
        post slot_rules_path, params: valid_params
      end.to change(SlotRule, :count).by(1)

      expect(response).to redirect_to(
        slot_rules_path(locale: I18n.locale)
      )

      follow_redirect!

      expect(response.body).to include("Rule created.")
    end

    it "creates slot rule for current user" do
      post slot_rules_path, params: valid_params

      expect(SlotRule.last.user).to eq(user)
    end

    it "renders index when invalid" do
      expect do
        post slot_rules_path, params: invalid_params
      end.not_to change(SlotRule, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("error")
    end
  end

  describe "GET /edit" do
    it "renders edit page" do
      get edit_slot_rule_path(slot_rule)

      expect(response).to have_http_status(:ok)
    end

    it "does not allow access to another user slot rule" do
      other_rule = create(
        :slot_rule,
        user: create(:user)
      )

      get edit_slot_rule_path(other_rule)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /update" do
    it "updates slot rule" do
      patch slot_rule_path(slot_rule), params: {
        slot_rule: {
          weekdays: %w[tuesday thursday]
        }
      }

      expect(response).to redirect_to(
        slot_rules_path(locale: I18n.locale)
      )

      expect(slot_rule.reload.weekdays)
        .to match_array(%w[tuesday thursday])
    end

    it "renders edit when invalid" do
      patch slot_rule_path(slot_rule), params: invalid_params

      expect(response)
        .to have_http_status(:unprocessable_content)
    end

    it "does not allow updating another user slot rule" do
      other_rule = create(
        :slot_rule,
        user: create(:user)
      )

      patch slot_rule_path(other_rule), params: valid_params

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /destroy" do
    it "destroys slot rule" do
      slot_rule

      expect do
        delete slot_rule_path(slot_rule)
      end.to change(SlotRule, :count).by(-1)

      expect(response).to redirect_to(
        slot_rules_path(locale: I18n.locale)
      )
    end

    it "does not allow deleting another user slot rule" do
      other_rule = create(
        :slot_rule,
        user: create(:user)
      )

      delete slot_rule_path(other_rule)

      expect(response).to have_http_status(:not_found)
    end
  end
end

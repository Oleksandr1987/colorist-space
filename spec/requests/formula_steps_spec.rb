require "rails_helper"

RSpec.describe "FormulaSteps" do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user, :trial) }
  let(:client) { create(:client, user: user) }
  let(:service_note) { create(:service_note, client: client, user: user) }
  let(:formula_step) { create(:formula_step, service_note: service_note) }

  before do
    sign_in user
  end

  describe "POST /formula_steps" do
    it "creates a formula step" do
      expect do
        post client_service_note_formula_steps_path(client, service_note), params: {
          formula_step: {
            section: "roots",
            oxidant: "6%",
            time: 30
          }
        }
      end.to change(FormulaStep, :count).by(1)

      expect(response).to redirect_to(client_service_note_path(client, service_note, locale: I18n.locale))
    end

    it "renders show when formula step invalid" do
      expect do
        post client_service_note_formula_steps_path(client, service_note), params: {
          formula_step: {
            section: nil
          }
        }
      end.not_to change(FormulaStep, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /formula_steps/:id" do
    it "updates the formula step" do
      oxidant_data = {
        service_id: 1,
        ratio: "1:2",
        amount: 30
      }

      patch client_service_note_formula_step_path(client, service_note, formula_step), params: {
        formula_step: {
          oxidant: oxidant_data.to_json
        }
      }

      expect(response).to redirect_to(
        client_service_note_path(client, service_note, locale: I18n.locale)
      )

      expect(formula_step.reload.oxidant_data).to eq(
        [
          {
          "service_id" => 1,
          "ratio" => "1:2",
          "amount" => 30
          }
        ]
      )
    end

    it "renders show when update invalid" do
      patch client_service_note_formula_step_path(
        client,
        service_note,
        formula_step
      ), params: {
        formula_step: {
          section: nil
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /formula_steps/:id" do
    it "destroys the formula step" do
      formula_step

      expect do
        delete client_service_note_formula_step_path(client, service_note, formula_step)
      end.to change(FormulaStep, :count).by(-1)

      expect(response).to redirect_to(client_service_note_path(client, service_note, locale: I18n.locale))
    end
  end

  describe "PATCH /clear_oxidant" do
    it "clears oxidant value" do
      formula_step.update!(oxidant: "6%")

      patch clear_oxidant_client_service_note_formula_step_path(client, service_note, formula_step)

      expect(formula_step.reload.oxidant).to be_nil
    end
  end

  describe "PATCH /clear_time" do
    it "clears time value" do
      formula_step.update!(time: 45)

      patch clear_time_client_service_note_formula_step_path(client, service_note, formula_step)

      expect(formula_step.reload.time).to be_nil
    end
  end
end

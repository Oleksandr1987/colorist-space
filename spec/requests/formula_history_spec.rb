# frozen_string_literal: true

require "rails_helper"

RSpec.describe "FormulaHistory" do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user, :trial) }
  let(:client) { create(:client, user: user) }
  let(:appointment) { create(:appointment, user: user, client: client, appointment_date: Date.current + 1.day) }
  let(:target_note) { create(:service_note, user: user, client: client, appointment: appointment) }
  let(:formula_note_sequence) { Hash.new(0) }

  before { sign_in user, scope: :user }

  def create_formula_note(client:, user:, date: nil, sections: [ "roots" ])
    formula_note_sequence[user.id] += 1
    sequence = formula_note_sequence[user.id]
    appointment = create(:appointment, user: user, client: client, appointment_date: date || Date.current - sequence.days)
    note = create(:service_note, user: user, client: client, appointment: appointment)
    sections.each { |section| create(:formula_step, service_note: note, section: section) }
    note
  end

  describe "GET /clients/:client_id/formula_history" do
    it "returns formula history for the current client" do
      note = create_formula_note(client: client, user: user, sections: [ "roots", "length" ])
      get client_formula_history_path(client), params: { target_service_note_id: target_note.id }
      json = response.parsed_body

      expect(response).to have_http_status(:ok)
      expect(json["formulas"].size).to eq(1)
      expect(json["formulas"].first).to include("id" => note.id, "steps_count" => 2, "sections" => [ "roots", "length" ])
      expect(json).to include("page" => 1, "total" => 1, "has_more" => false)
    end

    it "does not return service notes without formula steps" do
      empty_appointment = create(:appointment, user: user, client: client, appointment_date: Date.current - 30.days)
      create(:service_note, user: user, client: client, appointment: empty_appointment)

      get client_formula_history_path(client), params: { target_service_note_id: target_note.id }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("formulas" => [], "total" => 0)
    end

    it "does not return formulas belonging to another client" do
      other_client = create(:client, user: user)
      own_note = create_formula_note(client: client, user: user)
      create_formula_note(client: other_client, user: user)

      get client_formula_history_path(client), params: { target_service_note_id: target_note.id }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["formulas"].pluck("id")).to eq([ own_note.id ])
    end

    it "does not return formulas belonging to another user" do
      other_user = create(:user, :trial)
      other_client = create(:client, user: other_user)
      own_note = create_formula_note(client: client, user: user)
      create_formula_note(client: other_client, user: other_user)

      get client_formula_history_path(client), params: { target_service_note_id: target_note.id }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["formulas"].pluck("id")).to eq([ own_note.id ])
    end

    it "rejects a target service note that already contains formula steps" do
      create(:formula_step, service_note: target_note, section: "roots")

      get client_formula_history_path(client), params: { target_service_note_id: target_note.id }

      expect(response).to have_http_status(:not_found)
    end

    it "returns only 10 formulas per page" do
      12.times { create_formula_note(client: client, user: user) }

      get client_formula_history_path(client), params: { target_service_note_id: target_note.id }
      json = response.parsed_body

      expect(response).to have_http_status(:ok)
      expect(json["formulas"].size).to eq(10)
      expect(json).to include("page" => 1, "total" => 12, "has_more" => true)
    end

    it "returns remaining formulas on the second page" do
      12.times { create_formula_note(client: client, user: user) }

      get client_formula_history_path(client), params: { target_service_note_id: target_note.id, page: 2 }
      json = response.parsed_body

      expect(response).to have_http_status(:ok)
      expect(json["formulas"].size).to eq(2)
      expect(json).to include("page" => 2, "total" => 12, "has_more" => false)
    end

    it "normalizes negative page numbers to the first page" do
      create_formula_note(client: client, user: user)

      get client_formula_history_path(client), params: { target_service_note_id: target_note.id, page: -5 }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["page"]).to eq(1)
    end

    it "filters formulas by appointment date" do
      matching_date = Date.current - 10.days
      matching_note = create_formula_note(client: client, user: user, date: matching_date)
      create_formula_note(client: client, user: user, date: Date.current - 20.days)

      get client_formula_history_path(client),
        params: { target_service_note_id: target_note.id, search: matching_date.strftime("%d.%m.%Y") }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["formulas"].pluck("id")).to eq([ matching_note.id ])
      expect(response.parsed_body["total"]).to eq(1)
    end

    it "returns empty history for an invalid date" do
      create_formula_note(client: client, user: user)

      get client_formula_history_path(client), params: { target_service_note_id: target_note.id, search: "31.02.2026" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("formulas" => [], "total" => 0)
    end

    it "does not filter history for non-date search text" do
      create_formula_note(client: client, user: user)

      get client_formula_history_path(client), params: { target_service_note_id: target_note.id, search: "Wella" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["total"]).to eq(1)
    end

    it "allows history access when creating a new service note" do
      note = create_formula_note(client: client, user: user)
      new_appointment = create(:appointment, user: user, client: client)

      get client_formula_history_path(client), params: { appointment_id: new_appointment.id }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["formulas"].first["id"]).to eq(note.id)
    end

    it "rejects access without a target service note or appointment" do
      get client_formula_history_path(client)

      expect(response).to have_http_status(:not_found)
    end

    it "rejects a target service note belonging to another client" do
      other_client = create(:client, user: user)
      other_appointment = create(:appointment, user: user, client: other_client)
      other_target = create(:service_note, user: user, client: other_client, appointment: other_appointment)

      get client_formula_history_path(client), params: { target_service_note_id: other_target.id }

      expect(response).to have_http_status(:not_found)
    end

    it "rejects an appointment belonging to another client" do
      other_client = create(:client, user: user)
      other_appointment = create(:appointment, user: user, client: other_client)

      get client_formula_history_path(client), params: { appointment_id: other_appointment.id }

      expect(response).to have_http_status(:not_found)
    end

    it "rejects a new target appointment that already has a service note" do
      get client_formula_history_path(client), params: { appointment_id: target_note.appointment_id }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /clients/:client_id/formula_history/:service_note_id" do
    it "returns formula steps and ingredients" do
      note = create_formula_note(client: client, user: user)
      product = create(:formula_product, user: user, category: "color", brand: "Wella", name: "Koleston", unit: "g", price_per_unit: 15)
      create(:formula_ingredient, formula_step: note.formula_steps.first, formula_product: product,
        shade: "7/1", brand: "Wella", amount: 30, price: 15, kind: "color")

      get client_formula_history_entry_path(client, note), params: { target_service_note_id: target_note.id }
      json = response.parsed_body
      ingredient = json["steps"].first["ingredients"].first

      expect(response).to have_http_status(:ok)
      expect(json["id"]).to eq(note.id)
      expect(json["steps"].size).to eq(1)
      expect(json["steps"].first["section"]).to eq("roots")
      expect(ingredient)
        .to include("shade" => "7/1", "brand" => "Wella", "kind" => "color", "formula_product_id" => product.id, "unit" => "g")
      expect(ingredient["amount"].to_d).to eq(30.to_d)
      expect(ingredient["price"].to_d).to eq(15.to_d)
    end

    it "returns oxidant data for a formula step" do
      note = create_formula_note(client: client, user: user)
      oxidant_data = [ { formula_product_id: 123, brand: "Wella", name: "6%", amount: 45, price: 2, ratio: "1:1.5" } ]
      note.formula_steps.first.update!(oxidant: oxidant_data.to_json, time: 35)

      get client_formula_history_entry_path(client, note), params: { target_service_note_id: target_note.id }
      result = response.parsed_body["steps"].first

      expect(response).to have_http_status(:ok)
      expect(result["time"]).to eq(35)
      expect(result["oxidant"]).to eq(oxidant_data.map(&:stringify_keys))
    end

    it "returns all formula steps in id order" do
      note = create_formula_note(client: client, user: user, sections: [ "roots", "length", "strands" ])

      get client_formula_history_entry_path(client, note), params: { target_service_note_id: target_note.id }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["steps"].pluck("section")).to eq([ "roots", "length", "strands" ])
    end

    it "does not return formulas belonging to another client" do
      other_client = create(:client, user: user)
      other_note = create_formula_note(client: other_client, user: user)

      get client_formula_history_entry_path(client, other_note), params: { target_service_note_id: target_note.id }

      expect(response).to have_http_status(:not_found)
    end

    it "does not return formulas belonging to another user" do
      other_user = create(:user, :trial)
      other_client = create(:client, user: other_user)
      other_note = create_formula_note(client: other_client, user: other_user)

      get client_formula_history_entry_path(client, other_note), params: { target_service_note_id: target_note.id }

      expect(response).to have_http_status(:not_found)
    end

    it "does not allow importing the target service note itself" do
      get client_formula_history_entry_path(client, target_note), params: { target_service_note_id: target_note.id }

      expect(response).to have_http_status(:not_found)
    end

    it "allows reading history when creating a new service note" do
      note = create_formula_note(client: client, user: user)
      new_appointment = create(:appointment, user: user, client: client)

      get client_formula_history_entry_path(client, note), params: { appointment_id: new_appointment.id }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["id"]).to eq(note.id)
    end

    it "rejects access without a target service note or appointment" do
      note = create_formula_note(client: client, user: user)

      get client_formula_history_entry_path(client, note)

      expect(response).to have_http_status(:not_found)
    end

    it "preloads formula ingredients for all steps" do
      note = create_formula_note(client: client, user: user, sections: [ "roots", "length", "strands" ])

      note.formula_steps.each do |step|
        product = create(:formula_product, user: user, category: "color", brand: "Wella", unit: "g")

        create(:formula_ingredient, formula_step: step, formula_product: product)
      end

      queries = []

      subscriber = lambda do |_name, _started, _finished, _unique_id, payload|
        sql = payload[:sql]
        queries << sql if sql.match?(/\bFROM\s+["`]?formula_ingredients["`]?\b/i)
      end

      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        get client_formula_history_entry_path(client, note), params: { target_service_note_id: target_note.id }
      end

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["steps"].size).to eq(3)
      expect(queries.size).to eq(1)
    end
  end

  describe "authentication" do
    it "redirects unauthenticated users to sign in" do
      sign_out :user

      get client_formula_history_path(client), params: { target_service_note_id: target_note.id }

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end

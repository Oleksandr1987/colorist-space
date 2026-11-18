# frozen_string_literal: true

class AddCareProductsToServiceNotes < ActiveRecord::Migration[8.1]
  def change
    add_column :service_notes, :care_products, :json, default: -> { "(JSON_ARRAY())" }
  end
end

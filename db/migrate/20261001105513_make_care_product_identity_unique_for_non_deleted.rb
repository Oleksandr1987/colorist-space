# frozen_string_literal: true

class MakeCareProductIdentityUniqueForNonDeleted < ActiveRecord::Migration[8.1]
  def change
    remove_index :care_products, name: "index_care_products_on_unique_identity"

    add_index :care_products,
      %i[user_id normalized_brand normalized_name normalized_category],
      unique: true,
      where: "deleted_at IS NULL",
      name: "index_care_products_on_unique_identity"
  end
end

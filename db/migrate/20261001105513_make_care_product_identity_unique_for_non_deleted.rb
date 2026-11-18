# frozen_string_literal: true

class MakeCareProductIdentityUniqueForNonDeleted < ActiveRecord::Migration[8.1]
  def up
    remove_index :care_products,
      name: "index_care_products_on_unique_identity"

    execute <<~SQL
      ALTER TABLE care_products
      ADD COLUMN active_identity TINYINT
      GENERATED ALWAYS AS (CASE WHEN deleted_at IS NULL THEN 1 ELSE NULL END) STORED
    SQL

    add_index :care_products,
      %i[
        user_id
        normalized_brand
        normalized_name
        normalized_category
        active_identity
      ],
      unique: true,
      name: "index_care_products_on_unique_identity"
  end

  def down
    remove_index :care_products, name: "index_care_products_on_unique_identity"

    remove_column :care_products, :active_identity

    add_index :care_products,
      %i[
        user_id
        normalized_brand
        normalized_name
        normalized_category
      ],
      unique: true,
      name: "index_care_products_on_unique_identity"
  end
end

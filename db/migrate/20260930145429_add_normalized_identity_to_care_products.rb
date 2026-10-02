# frozen_string_literal: true

class AddNormalizedIdentityToCareProducts < ActiveRecord::Migration[8.1]
  class MigrationCareProduct < ActiveRecord::Base
    self.table_name = "care_products"
  end

  def up
    add_column :care_products, :normalized_brand, :string
    add_column :care_products, :normalized_name, :string
    add_column :care_products, :normalized_category, :string

    MigrationCareProduct.reset_column_information

    MigrationCareProduct.find_each do |product|
      product.update_columns(
        normalized_brand: normalize(product.brand),
        normalized_name: normalize(product.name),
        normalized_category: normalize(product.category)
      )
    end

    change_column_null :care_products, :normalized_brand, false
    change_column_null :care_products, :normalized_name, false
    change_column_null :care_products, :normalized_category, false

    add_index :care_products,
      %i[user_id normalized_brand normalized_name normalized_category],
      unique: true,
      name: "index_care_products_on_unique_identity"
  end

  def down
    remove_index :care_products, name: "index_care_products_on_unique_identity"

    remove_column :care_products, :normalized_brand
    remove_column :care_products, :normalized_name
    remove_column :care_products, :normalized_category
  end

  private

  def normalize(value)
    value.to_s
      .unicode_normalize(:nfkc)
      .squish
      .downcase
  end
end

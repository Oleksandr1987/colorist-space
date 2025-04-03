class AddCategoryAndSubtypeToServices < ActiveRecord::Migration[8.0]
  def change
    add_column :services, :category, :string
    add_column :services, :subtype, :string
    add_index :services, [ :user_id, :category, :subtype ], unique: true
  end
end

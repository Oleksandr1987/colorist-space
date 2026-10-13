class AddHairDamageLevelToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :hair_damage_level, :integer
  end
end

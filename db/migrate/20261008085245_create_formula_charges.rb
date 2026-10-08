class CreateFormulaCharges < ActiveRecord::Migration[8.1]
  def change
    create_table :formula_charges do |t|
      t.references :user, null: false, foreign_key: true
      t.references :appointment, null: false, foreign_key: true

      t.references :service_note,
        null: true,
        foreign_key: { on_delete: :nullify }

      t.references :formula_product,
        null: true,
        foreign_key: { on_delete: :nullify }

      t.string :kind, null: false
      t.string :brand
      t.string :product_name, null: false
      t.decimal :amount, precision: 12, scale: 3, null: false
      t.string :unit
      t.decimal :unit_price, precision: 12, scale: 4, null: false
      t.decimal :total, precision: 12, scale: 2, null: false

      t.timestamps
    end

    add_index :formula_charges, :kind
  end
end

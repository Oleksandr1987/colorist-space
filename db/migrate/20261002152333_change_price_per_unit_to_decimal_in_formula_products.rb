class ChangePricePerUnitToDecimalInFormulaProducts < ActiveRecord::Migration[8.1]
  def change
    change_column :formula_products,
      :price_per_unit,
      :decimal,
      precision: 10,
      scale: 2
  end
end

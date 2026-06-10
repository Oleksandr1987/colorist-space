class ChangeCareProductPricesToDecimal < ActiveRecord::Migration[8.1]
  def change
    change_column :care_products,
                  :purchase_price,
                  :decimal,
                  precision: 10,
                  scale: 2

    change_column :care_products,
                  :sale_price,
                  :decimal,
                  precision: 10,
                  scale: 2
  end
end

class AddHaircutAndFormulaNotesToServiceNotes < ActiveRecord::Migration[8.1]
  def change
    add_column :service_notes, :haircut_notes, :text
    add_column :service_notes, :formula_notes, :text
  end
end

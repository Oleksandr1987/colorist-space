class AddMainPhotoIdToServiceNotes < ActiveRecord::Migration[8.1]
  def change
    add_column :service_notes, :main_photo_id, :integer
  end
end

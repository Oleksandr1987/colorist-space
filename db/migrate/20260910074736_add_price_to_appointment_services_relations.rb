class AddPriceToAppointmentServicesRelations < ActiveRecord::Migration[8.1]
  def up
    add_column :appointment_services_relations, :price, :integer

    relation_class = Class.new(ActiveRecord::Base) do
      self.table_name = "appointment_services_relations"
    end

    service_class = Class.new(ActiveRecord::Base) do
      self.table_name = "services"
    end

    relation_class.reset_column_information

    relation_class.find_in_batches do |relations|
      service_ids = relations.map(&:service_id).uniq
      prices = service_class.where(id: service_ids).pluck(:id, :price).to_h

      relations.each do |relation|
        relation.update_columns(price: prices.fetch(relation.service_id))
      end
    end

    change_column_null :appointment_services_relations, :price, false
  end

  def down
    remove_column :appointment_services_relations, :price
  end
end

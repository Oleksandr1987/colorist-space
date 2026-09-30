require "rails_helper"

RSpec.describe CareProducts::CancelServiceNoteSales do
  subject(:cancel) { described_class.new(service_note: service_note) }

  let(:user) { create(:user) }
  let(:client) { create(:client, user: user) }
  let(:appointment) { create(:appointment, user: user, client: client) }
  let(:care_product) { create(:care_product, user: user, purchase_price: 60, sale_price: 100, stock_quantity: 10) }
  let(:care_products) { [ { "care_product_id" => care_product.id, "price" => 100, "purchase_price" => 60, "qty" => 3 } ] }
  let(:service_note) { create(:service_note, user: user, client: client, appointment: appointment, care_products: care_products) }

  describe "#call" do
    it "removes sale" do
      service_note

      expect { cancel.call }.to change(service_note.care_product_sales, :count).from(1).to(0)
    end

    it "restores stock" do
      service_note

      expect { cancel.call }.to change { care_product.reload.stock_quantity }.from(7).to(10)
    end

    it "creates positive adjustment movement" do
      service_note

      expect { cancel.call }.to change(user.care_product_stock_movements, :count).by(1)

      movement = user.care_product_stock_movements.order(:id).last

      expect(movement.movement_type).to eq("adjustment")
      expect(movement.adjustment_reason).to eq("service_note_cancel")
      expect(movement.quantity).to eq(3)
      expect(movement.unit_cost).to eq(60)
      expect(movement.occurred_on).to eq(appointment.appointment_date)
    end

    it "links adjustment movement to service note" do
      service_note

      cancel.call

      movement = user.care_product_stock_movements.order(:id).last

      expect(movement.service_note).to eq(service_note)
      expect(movement.care_product).to eq(care_product)
    end

    it "keeps original sale movement" do
      service_note

      sale_movement = service_note.care_product_sales.first.stock_movement

      cancel.call

      expect(CareProductStockMovement.exists?(sale_movement.id)).to be(true)
      expect(sale_movement.reload.movement_type).to eq("sale")
      expect(sale_movement.quantity).to eq(-3)
    end

    context "with multiple sales" do
      let(:second_product) { create(:care_product, user: user, name: "Mask", purchase_price: 40, sale_price: 70, stock_quantity: 5) }

      let(:care_products) do
        [
          { "care_product_id" => care_product.id, "price" => 100, "purchase_price" => 60, "qty" => 3 },
          { "care_product_id" => second_product.id, "price" => 70, "purchase_price" => 40, "qty" => 2 }
        ]
      end

      it "removes all sales" do
        service_note

        expect { cancel.call }.to change(service_note.care_product_sales, :count).from(2).to(0)
      end

      it "restores stock for all products" do
        service_note

        cancel.call

        expect(care_product.reload.stock_quantity).to eq(10)
        expect(second_product.reload.stock_quantity).to eq(5)
      end

      it "creates adjustment movement for each sale" do
        service_note

        expect { cancel.call }.to change {
          user.care_product_stock_movements.where(movement_type: "adjustment").count
        }.by(2)

        reasons = user.care_product_stock_movements.where(movement_type: "adjustment").pluck(:adjustment_reason)

        expect(reasons).to contain_exactly("service_note_cancel", "service_note_cancel")
      end
    end

    context "without sales" do
      let(:care_products) { [] }

      it "does not change stock movements" do
        service_note

        expect { cancel.call }.not_to change(CareProductStockMovement, :count)
      end
    end

    context "when cancellation fails" do
      before do
        service_note

        stock_movements = service_note.user.care_product_stock_movements

        allow(stock_movements)
          .to receive(:create!)
          .and_raise(ActiveRecord::RecordInvalid)
      end

      it "raises an error" do
        expect { cancel.call }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "does not create adjustment movement" do
        expect { cancel.call rescue nil }.not_to change {
          user.care_product_stock_movements.where(movement_type: "adjustment").count
        }
      end

      it "does not remove sale" do
        expect { cancel.call rescue nil }.not_to change(service_note.care_product_sales, :count)
      end

      it "does not change stock" do
        expect { cancel.call rescue nil }.not_to change { care_product.reload.stock_quantity }
      end
    end
  end
end

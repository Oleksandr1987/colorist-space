require "rails_helper"

RSpec.describe CareProducts::SyncServiceNoteSales do
  subject(:sync) { described_class.new(service_note: service_note) }

  let(:user) { create(:user) }
  let(:client) { create(:client, user: user) }
  let(:appointment) { create(:appointment, user: user, client: client) }
  let(:care_product) { create(:care_product, user: user, purchase_price: 60, sale_price: 100, stock_quantity: 10) }
  let(:care_products) { [ { "care_product_id" => care_product.id, "price" => 100, "purchase_price" => 60, "qty" => 2 } ] }
  let(:service_note) { create(:service_note, user: user, client: client, appointment: appointment, care_products: care_products) }

  describe "#call" do
    context "when quantity increases" do
      before do
        service_note
        service_note.update_column(:care_products,
          [ { "care_product_id" => care_product.id, "price" => 100, "purchase_price" => 60, "qty" => 5 } ]
        )
      end

      it "updates sale quantity" do
        expect { sync.call }.to change { service_note.care_product_sales.first.reload.quantity }.from(2).to(5)
      end

      it "decreases stock by quantity difference" do
        expect { sync.call }.to change { care_product.reload.stock_quantity }.from(8).to(5)
      end

      it "creates negative adjustment movement" do
        expect { sync.call }.to change(user.care_product_stock_movements, :count).by(1)

        movement = user.care_product_stock_movements.last

        expect(movement.movement_type).to eq("adjustment")
        expect(movement.adjustment_reason).to eq("service_note_sync")
        expect(movement.quantity).to eq(-3)
        expect(movement.unit_cost).to eq(60)
        expect(movement.stock_after).to eq(5)
        expect(movement.stock_after).to eq(care_product.reload.stock_quantity)
      end
    end

    context "when quantity decreases" do
      before do
        service_note
        service_note.update_column(:care_products,
          [ { "care_product_id" => care_product.id, "price" => 100, "purchase_price" => 60, "qty" => 1 } ]
        )
      end

      it "updates sale quantity" do
        expect { sync.call }.to change { service_note.care_product_sales.first.reload.quantity }.from(2).to(1)
      end

      it "restores stock by quantity difference" do
        expect { sync.call }.to change { care_product.reload.stock_quantity }.from(8).to(9)
      end

      it "creates positive adjustment movement" do
        sync.call

        movement = user.care_product_stock_movements.last

        expect(movement.movement_type).to eq("adjustment")
        expect(movement.adjustment_reason).to eq("service_note_sync")
        expect(movement.quantity).to eq(1)
        expect(movement.unit_cost).to eq(60)
        expect(movement.stock_after).to eq(9)
        expect(movement.stock_after).to eq(care_product.reload.stock_quantity)
      end
    end

    context "when quantity does not change" do
      before { service_note }

      it "does not change stock" do
        expect { sync.call }.not_to change { care_product.reload.stock_quantity }
      end

      it "does not create stock movement" do
        expect { sync.call }.not_to change(CareProductStockMovement, :count)
      end
    end

    context "when sale price changes" do
      before do
        service_note
        service_note.update_column(:care_products,
          [ { "care_product_id" => care_product.id, "price" => 120, "purchase_price" => 60, "qty" => 2 } ]
        )
      end

      it "updates unit price" do
        expect { sync.call }.to change { service_note.care_product_sales.first.reload.unit_price }.from(100).to(120)
      end

      it "does not change stock" do
        expect { sync.call }.not_to change { care_product.reload.stock_quantity }
      end
    end

    context "when a new product is added" do
      let(:second_product) { create(:care_product, user: user, name: "Mask", purchase_price: 40, sale_price: 70, stock_quantity: 5) }

      before do
        service_note
        service_note.update_column(
          :care_products,
          [
            { "care_product_id" => care_product.id, "price" => 100, "purchase_price" => 60, "qty" => 2 },
            { "care_product_id" => second_product.id, "price" => 70, "purchase_price" => 40, "qty" => 3 }
          ]
        )
      end

      it "creates a new sale" do
        expect { sync.call }.to change(service_note.care_product_sales, :count).by(1)
      end

      it "decreases new product stock" do
        expect { sync.call }.to change { second_product.reload.stock_quantity }.from(5).to(2)
      end

      it "creates sale movement for new product" do
        sync.call

        sale = service_note.care_product_sales.find_by(care_product: second_product)

        expect(sale.quantity).to eq(3)
        expect(sale.unit_price).to eq(70)
        expect(sale.unit_cost).to eq(40)
        expect(sale.stock_movement.movement_type).to eq("sale")
        expect(sale.stock_movement.quantity).to eq(-3)
        expect(sale.stock_movement.stock_after).to eq(2)
        expect(sale.stock_movement.stock_after).to eq(second_product.reload.stock_quantity)
      end
    end

    context "when product is removed" do
      before do
        service_note
        service_note.update_column(:care_products, [])
      end

      it "removes sale" do
        expect { sync.call }.to change(service_note.care_product_sales, :count).from(1).to(0)
      end

      it "restores stock" do
        expect { sync.call }.to change { care_product.reload.stock_quantity }.from(8).to(10)
      end

      it "creates positive adjustment movement" do
        sync.call

        movement = user.care_product_stock_movements.last

        expect(movement.movement_type).to eq("adjustment")
        expect(movement.adjustment_reason).to eq("service_note_sync")
        expect(movement.quantity).to eq(2)
        expect(movement.unit_cost).to eq(60)
        expect(movement.stock_after).to eq(10)
        expect(movement.stock_after).to eq(care_product.reload.stock_quantity)
      end
    end

    context "when additional quantity exceeds available stock" do
      before do
        service_note
        service_note.update_column(:care_products,
          [ { "care_product_id" => care_product.id, "price" => 100, "purchase_price" => 60, "qty" => 11 } ]
        )
      end

      it "raises an error" do
        expect { sync.call }.to raise_error(ArgumentError, I18n.t("care_products.errors.not_enough_stock"))
      end

      it "does not change sale quantity" do
        expect { sync.call rescue nil }.not_to change { service_note.care_product_sales.first.reload.quantity }
      end

      it "does not change stock" do
        expect { sync.call rescue nil }.not_to change { care_product.reload.stock_quantity }
      end
    end

    context "when synchronization fails" do
      before do
        service_note
        service_note.update_column(:care_products,
          [ { "care_product_id" => care_product.id, "price" => 100, "purchase_price" => 60, "qty" => 5 } ]
        )

        allow(service_note.user.care_product_stock_movements).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
      end

      it "rolls back sale changes" do
        expect { sync.call rescue nil }.not_to change { service_note.care_product_sales.first.reload.quantity }
      end

      it "rolls back stock changes" do
        expect { sync.call rescue nil }.not_to change { care_product.reload.stock_quantity }
      end
    end

    context "when existing sale product is archived" do
      before do
        service_note
        care_product.update!(archived_at: Time.current)
      end

      context "when quantity increases" do
        it "raises an error" do
          service_note.care_products = [ { "care_product_id" => care_product.id.to_s, "qty" => 3, "price" => 100 } ]

          expect { sync.call }.to raise_error(ArgumentError, I18n.t("care_products.errors.archived_product"))
        end
      end

      context "when quantity decreases" do
        it "raises an error" do
          service_note.care_products = [ { "care_product_id" => care_product.id.to_s, "qty" => 1, "price" => 100 } ]

          expect { sync.call }.to raise_error(ArgumentError, I18n.t("care_products.errors.archived_product"))
        end
      end

      context "when existing sale product is archived" do
        before do
          service_note
          care_product.update!(archived_at: Time.current)
        end

        context "when only sale price changes" do
          it "allows historical correction" do
            service_note.care_products = [ { "care_product_id" => care_product.id.to_s, "qty" => 2, "price" => 120 } ]

            expect { sync.call }.not_to raise_error
            expect(service_note.care_product_sales.first.reload.unit_price).to eq(120)
          end
        end

        context "when product is removed" do
          it "raises an error" do
            service_note.care_products = []

            expect { sync.call }.to raise_error(ArgumentError, I18n.t("care_products.errors.archived_product"))
          end
        end
      end
    end

    context "when existing sale product is deleted" do
      before do
        service_note
        care_product.update!(deleted_at: Time.current)
      end

      context "when quantity increases" do
        it "raises an error" do
          service_note.care_products = [ { "care_product_id" => care_product.id.to_s, "qty" => 3, "price" => 100 } ]

          expect { sync.call }.to raise_error(ArgumentError, I18n.t("care_products.errors.deleted_product"))
        end
      end

      context "when quantity decreases" do
        it "raises an error" do
          service_note.care_products = [ { "care_product_id" => care_product.id.to_s, "qty" => 1, "price" => 100 } ]

          expect { sync.call }.to raise_error(ArgumentError, I18n.t("care_products.errors.deleted_product"))
        end
      end

      context "when product is removed" do
        it "raises an error" do
          service_note.care_products = []

          expect { sync.call }.to raise_error(ArgumentError, I18n.t("care_products.errors.deleted_product"))
        end
      end
    end
  end
end

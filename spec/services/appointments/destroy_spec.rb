# frozen_string_literal: true

require "rails_helper"

RSpec.describe Appointments::Destroy do
  let(:user) { create(:user) }
  let(:client) { create(:client, user: user) }
  let(:appointment) { create(:appointment, user: user, client: client) }

  def sell_product(product:, quantity:, service_note: nil)
    CareProducts::Sell.new(
      user: user,
      care_product: product,
      quantity: quantity,
      unit_price: product.sale_price,
      sold_on: Date.current,
      service_note: service_note
    ).call
  end

  describe "#call" do
    context "without care product sales" do
      it "destroys the appointment" do
        appointment
        expect { described_class.new(appointment: appointment).call }.to change(Appointment, :count).by(-1)
      end
    end

    context "with a care product sale" do
      let(:product) { create(:care_product, user: user, stock_quantity: 10) }
      let(:service_note) { create(:service_note, user: user, client: client, appointment: appointment) }

      let!(:sale) do
        CareProducts::Sell.new(user: user, care_product: product,
          quantity: 2, unit_price: 100, sold_on: Date.current, service_note: service_note).call
      end

      it "restores the sold quantity" do
        expect { described_class.new(appointment: appointment).call }.to change { product.reload.stock_quantity }.from(8).to(10)
      end

      it "removes the appointment sale" do
        expect { described_class.new(appointment: appointment).call }.to change { CareProductSale.where(id: sale.id).count }.from(1).to(0)
      end

      it "creates a cancellation movement" do
        described_class.new(appointment: appointment).call

        movement = product.stock_movements.find_by!(adjustment_reason: "appointment_cancel")

        expect(movement.quantity).to eq(2)
        expect(movement.stock_after).to eq(10)
      end

      it "preserves the original sale movement" do
        original_movement_id = sale.stock_movement_id

        described_class.new(appointment: appointment).call

        expect(CareProductStockMovement.exists?(original_movement_id)).to be(true)
      end
    end

    context "with multiple care product sales" do
      let(:first_product) { create(:care_product, user: user, name: "Shampoo A", stock_quantity: 10) }
      let(:second_product) { create(:care_product, user: user, name: "Shampoo B", stock_quantity: 8) }
      let(:service_note) { create(:service_note, user: user, client: client, appointment: appointment) }

      before do
        sell_product(product: first_product, quantity: 2, service_note: service_note)
        sell_product(product: second_product, quantity: 3, service_note: service_note)
      end

      it "restores stock for every product" do
        expect {
          described_class.new(appointment: appointment).call
        }.to change { first_product.reload.stock_quantity }.from(8).to(10)
          .and change { second_product.reload.stock_quantity }.from(5).to(8)
      end

      it "creates a cancellation movement for each product" do
        described_class.new(appointment: appointment).call

        first_movement = first_product.stock_movements.find_by!(adjustment_reason: "appointment_cancel")
        second_movement = second_product.stock_movements.find_by!(adjustment_reason: "appointment_cancel")

        expect(first_movement.quantity).to eq(2)
        expect(first_movement.stock_after).to eq(10)

        expect(second_movement.quantity).to eq(3)
        expect(second_movement.stock_after).to eq(8)
      end
    end

    context "with appointment and direct sales" do
      let(:product) { create(:care_product, user: user, stock_quantity: 10) }
      let(:service_note) { create(:service_note, user: user, client: client, appointment: appointment) }
      let!(:appointment_sale) { sell_product(product: product, quantity: 2, service_note: service_note) }
      let!(:direct_sale) { sell_product(product: product, quantity: 3) }

      it "preserves direct sales and restores only appointment stock" do
        expect { described_class.new(appointment: appointment).call }.to change { product.reload.stock_quantity }.from(5).to(7)
        expect(CareProductSale.exists?(appointment_sale.id)).to be(false)
        expect(CareProductSale.exists?(direct_sale.id)).to be(true)
      end

      it "preserves the direct sale stock movement" do
        direct_movement_id = direct_sale.stock_movement_id

        described_class.new(appointment: appointment).call

        expect(CareProductStockMovement.exists?(direct_movement_id)).to be(true)
      end
    end

    context "when creating a cancellation movement fails" do
      let(:product) { create(:care_product, user: user, stock_quantity: 10) }
      let(:service_note) { create(:service_note, user: user, client: client, appointment: appointment) }
      let!(:sale) { sell_product(product: product, quantity: 2, service_note: service_note) }

      it "rolls back stock changes and preserves the appointment and sale" do
        movements = appointment.user.care_product_stock_movements

        allow(appointment.user).to receive(:care_product_stock_movements).and_return(movements)
        allow(movements).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

        expect { described_class.new(appointment: appointment).call }.to raise_error(ActiveRecord::RecordInvalid)

        expect(product.reload.stock_quantity).to eq(8)
        expect(Appointment.exists?(appointment.id)).to be(true)
        expect(CareProductSale.exists?(sale.id)).to be(true)
        expect(product.stock_movements.where(adjustment_reason: "appointment_cancel").count).to eq(0)
      end
    end

    context "when the second cancellation movement fails" do
      let(:first_product) { create(:care_product, user: user, name: "Rollback Shampoo", stock_quantity: 10) }
      let(:second_product) { create(:care_product, user: user, name: "Rollback Mask", stock_quantity: 8) }
      let(:service_note) { create(:service_note, user: user, client: client, appointment: appointment) }

      let!(:first_sale) { sell_product(product: first_product, quantity: 2, service_note: service_note) }
      let!(:second_sale) { sell_product(product: second_product, quantity: 3, service_note: service_note) }

      before do
        movements = appointment.user.care_product_stock_movements
        calls = 0

        allow(appointment.user).to receive(:care_product_stock_movements).and_return(movements)

        allow(movements).to receive(:create!).and_wrap_original do |original, **attributes|
          calls += 1
          raise ActiveRecord::RecordInvalid if calls == 2

          original.call(**attributes)
        end
      end

      def destroy_with_error
        described_class.new(appointment: appointment).call
      rescue ActiveRecord::RecordInvalid
        nil
      end

      it "raises an error on the second cancellation movement" do
        expect { described_class.new(appointment: appointment).call }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "rolls back stock changes for both products" do
        destroy_with_error

        expect(first_product.reload.stock_quantity).to eq(8)
        expect(second_product.reload.stock_quantity).to eq(5)
      end

      it "preserves the appointment and both sales" do
        destroy_with_error

        expect(Appointment.exists?(appointment.id)).to be(true)
        expect(CareProductSale.exists?(first_sale.id)).to be(true)
        expect(CareProductSale.exists?(second_sale.id)).to be(true)
      end

      it "rolls back the cancellation movements" do
        destroy_with_error

        expect(first_product.stock_movements.where(adjustment_reason: "appointment_cancel")).to be_empty
        expect(second_product.stock_movements.where(adjustment_reason: "appointment_cancel")).to be_empty
      end
    end

    context "when appointment destruction fails" do
      let(:product) { create(:care_product, user: user, stock_quantity: 10) }
      let(:service_note) { create(:service_note, user: user, client: client, appointment: appointment) }
      let!(:sale) { sell_product(product: product, quantity: 2, service_note: service_note) }

      it "rolls back the restored stock and cancellation movement" do
        allow(appointment).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed)

        expect { described_class.new(appointment: appointment).call }.to raise_error(ActiveRecord::RecordNotDestroyed)
        expect(product.reload.stock_quantity).to eq(8)
        expect(Appointment.exists?(appointment.id)).to be(true)
        expect(CareProductSale.exists?(sale.id)).to be(true)
        expect(product.stock_movements.where(adjustment_reason: "appointment_cancel").count).to eq(0)
      end
    end
  end
end

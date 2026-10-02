require "rails_helper"

RSpec.describe CareProduct do
  subject(:care_product) { build(:care_product) }

  let(:user) { create(:user) }

  it { is_expected.to belong_to(:user) }

  it { is_expected.to validate_presence_of(:name) }

  it do
    expect(care_product).to validate_numericality_of(:sale_price)
      .is_greater_than_or_equal_to(0)
      .allow_nil
  end

  it do
    expect(care_product).to validate_numericality_of(:purchase_price)
      .is_greater_than_or_equal_to(0)
      .allow_nil
  end

  it do
    expect(care_product).to validate_numericality_of(:stock_quantity)
      .is_greater_than_or_equal_to(0)
      .allow_nil
  end

  describe "scopes" do
    describe ".active" do
      it "returns only active products" do
        active_product = create(:care_product, archived_at: nil, deleted_at: nil)
        create(:care_product, archived_at: Time.current)
        create(:care_product, deleted_at: Time.current)

        expect(described_class.active).to contain_exactly(active_product)
      end
    end

    describe ".archived" do
      it "returns only archived products that are not deleted" do
        create(:care_product)
        archived_product = create(:care_product, archived_at: Time.current)
        create(:care_product, archived_at: 1.day.ago, deleted_at: Time.current)

        expect(described_class.archived).to contain_exactly(archived_product)
      end
    end

    describe ".deleted" do
      it "returns only deleted products" do
        create(:care_product)
        create(:care_product, archived_at: Time.current)
        deleted_product = create(:care_product, deleted_at: Time.current)

        expect(described_class.deleted).to contain_exactly(deleted_product)
      end
    end
  end

  describe "#active?" do
    it "returns true for active product" do
      expect(build(:care_product, archived_at: nil, deleted_at: nil)).to be_active
    end

    it "returns false for archived product" do
      expect(build(:care_product, archived_at: Time.current, deleted_at: nil)).not_to be_active
    end

    it "returns false for deleted product" do
      expect(build(:care_product, archived_at: nil, deleted_at: Time.current)).not_to be_active
    end
  end

  describe "#archived?" do
    it "returns false for active product" do
      care_product = build(:care_product, archived_at: nil)

      expect(care_product).not_to be_archived
    end

    it "returns true for archived product" do
      care_product = build(:care_product, archived_at: Time.current)

      expect(care_product).to be_archived
    end
  end

  describe "#archive!" do
    it "archives product with zero stock" do
      care_product = create(:care_product, stock_quantity: 0)

      expect { care_product.archive! }.to change { care_product.reload.archived_at }.from(nil)
    end

    it "does not archive product with remaining stock" do
      care_product = create(:care_product, stock_quantity: 5)

      expect { care_product.archive! }.to raise_error(ActiveRecord::RecordInvalid)
      expect(care_product.reload.archived_at).to be_nil
      expect(care_product.errors[:base]).to include(I18n.t("care_products.errors.cannot_archive_with_stock"))
    end

    it "does not archive deleted product" do
      care_product = create(:care_product, stock_quantity: 0, deleted_at: Time.current)

      expect(care_product.archive!).to be(false)
      expect(care_product.reload.archived_at).to be_nil
    end
  end

  describe "#restore!" do
    it "restores archived product" do
      care_product = create(:care_product, stock_quantity: 0, archived_at: 1.day.ago)

      expect { care_product.restore! }.to change { care_product.reload.archived_at }.to(nil)
    end

    it "does not restore deleted product" do
      care_product = create(:care_product, stock_quantity: 0, archived_at: 1.day.ago, deleted_at: Time.current)

      expect(care_product.restore!).to be(false)
      expect(care_product.reload).to be_deleted
    end
  end

  describe "#deleted?" do
    it "returns false for active product" do
      care_product = build(:care_product, deleted_at: nil)

      expect(care_product).not_to be_deleted
    end

    it "returns true for deleted product" do
      care_product = build(:care_product, deleted_at: Time.current)

      expect(care_product).to be_deleted
    end
  end

  describe "#soft_delete!" do
    it "soft deletes product with zero stock" do
      care_product = create(:care_product, stock_quantity: 0)

      expect { care_product.soft_delete! }.to change { care_product.reload.deleted_at }.from(nil)
      expect(care_product).to be_deleted
    end

    it "removes archived state when deleting archived product" do
      care_product = create(:care_product, stock_quantity: 0, archived_at: 1.day.ago)

      care_product.soft_delete!

      expect(care_product.reload.deleted_at).to be_present
      expect(care_product.archived_at).to be_nil
    end

    it "does not delete product with remaining stock" do
      care_product = create(:care_product, stock_quantity: 5)

      expect { care_product.soft_delete! }.to raise_error(ActiveRecord::RecordInvalid)
      expect(care_product.reload.deleted_at).to be_nil
      expect(care_product.errors[:base]).to include(I18n.t("care_products.errors.cannot_delete_with_stock"))
    end
  end

  describe "#incomplete?" do
    it "returns false when all required values present" do
      expect(build(:care_product, purchase_price: 100, stock_quantity: 10)).not_to be_incomplete
    end

    it "returns true when purchase_price is blank" do
      expect(build(:care_product, purchase_price: nil)).to be_incomplete
    end

    it "returns true when stock_quantity is blank" do
      expect(build(:care_product, stock_quantity: nil)).to be_incomplete
    end
  end

  describe "#stock_value" do
    it "returns purchase price multiplied by stock quantity" do
      product = build(:care_product, purchase_price: 800, stock_quantity: 60)

      expect(product.stock_value).to eq(48_000)
    end
  end

  describe ".total_stock_value" do
    it "returns total purchase value of products in stock" do
      create(:care_product, user: user, name: "Shampoo", purchase_price: 800, stock_quantity: 10)
      create(:care_product, user: user, name: "Mask", purchase_price: 500, stock_quantity: 9)

      expect(user.care_products.total_stock_value).to eq(12_500)
    end
  end

  describe "product identity" do
    it "normalizes identity fields" do
      product =
        create(:care_product, user: user, brand: "  L'Oréal   Professionnel ", name: "  ШАМПУНЬ   Від випадіння ", category: "  Догляд ")

      expect(product.brand).to eq("L'Oréal Professionnel")
      expect(product.name).to eq("ШАМПУНЬ Від випадіння")
      expect(product.category).to eq("Догляд")
      expect(product.normalized_brand).to eq("l'oréal professionnel")
      expect(product.normalized_name).to eq("шампунь від випадіння")
      expect(product.normalized_category).to eq("догляд")
    end

    it "does not allow duplicate products for the same user" do
      create(:care_product, user: user, brand: "Na Golovy", name: "Шампунь", category: "Догляд")

      duplicate = build(:care_product, user: user, brand: "Na Golovy", name: "Шампунь", category: "Догляд")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end

    it "checks duplicate identity case insensitively for Ukrainian text" do
      create(:care_product, user: user, brand: "Na Golovy", name: "Шампунь від випадіння", category: "Догляд")

      duplicate = build(:care_product, user: user, brand: "NA GOLOVY", name: "ШАМПУНЬ ВІД ВИПАДІННЯ", category: "ДОГЛЯД")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end

    it "checks duplicate identity ignoring extra whitespace" do
      create(:care_product, user: user, brand: "Na Golovy", name: "Шампунь від випадіння", category: "Догляд")

      duplicate = build(:care_product, user: user, brand: "  Na   Golovy ", name: " Шампунь   від випадіння ", category: " Догляд ")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end

    it "allows the same product for another user" do
      other_user = create(:user)

      create(:care_product, user: user, brand: "Na Golovy", name: "Шампунь", category: "Догляд")

      product = build(:care_product, user: other_user, brand: "NA GOLOVY", name: "ШАМПУНЬ", category: "ДОГЛЯД")

      expect(product).to be_valid
    end

    it "allows products with different names" do
      create(:care_product, user: user, brand: "Na Golovy", name: "Шампунь", category: "Догляд")

      product = build(:care_product, user: user, brand: "Na Golovy", name: "Маска", category: "Догляд")

      expect(product).to be_valid
    end

    it "allows products with different categories" do
      create(:care_product, user: user, brand: "Na Golovy", name: "Шампунь", category: "Догляд")

      product = build(:care_product, user: user, brand: "Na Golovy", name: "Шампунь", category: "Лікування")

      expect(product).to be_valid
    end

    it "allows updating the same product" do
      product = create(:care_product, user: user, brand: "Na Golovy", name: "Шампунь", category: "Догляд")

      product.sale_price = 1500

      expect(product).to be_valid
    end

    it "does not allow duplicate archived product identity" do
      create(:care_product, user: user, brand: "Londa", name: "Visible Repair", category: "Shampoo", archived_at: Time.current)

      duplicate = build(:care_product, user: user, brand: "Londa", name: "Visible Repair", category: "Shampoo")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include(I18n.t("care_products.errors.archived_duplicate"))
    end

    it "allows reusing identity of deleted product" do
      create(:care_product, user: user, brand: "Londa", name: "Visible Repair", category: "Shampoo", deleted_at: Time.current)

      duplicate = build(:care_product, user: user, brand: "Londa", name: "Visible Repair", category: "Shampoo")

      expect(duplicate).to be_valid
    end

    it "allows duplicate identity when previous product is deleted" do
      deleted_product =
        create(:care_product, user: user, brand: "Londa", name: "Visible Repair", category: "Shampoo", deleted_at: Time.current)
      new_product =
        create(:care_product, user: user, brand: deleted_product.brand, name: deleted_product.name, category: deleted_product.category)

      expect(new_product).to be_persisted
      expect(new_product.id).not_to eq(deleted_product.id)
    end
  end

  describe "#display_name" do
    it "joins brand and name" do
      product = build(:care_product, brand: "Londa", name: "Shampoo")

      expect(product.display_name).to eq("Londa Shampoo")
    end
  end

  describe "broadcasts" do
    it "broadcasts append to user care products stream on create" do
      product = build(:care_product, user: user)

      allow(product).to receive(:broadcast_append_to)

      product.save!

      expect(product).to have_received(:broadcast_append_to).with(user, "care_products",
        target: "care_products", partial: "care_products/care_product", locals: { care_product: product })
    end

    it "broadcasts replace to user care products stream on update" do
      product = create(:care_product, user: user)

      allow(product).to receive(:broadcast_replace_to)

      product.update!(name: "New Name")

      expect(product).to have_received(:broadcast_replace_to).with(user, "care_products",
        target: "care_product_#{product.id}", partial: "care_products/care_product", locals: { care_product: product })
    end

    it "broadcasts remove when product is archived" do
      product = create(:care_product, user: user, stock_quantity: 0)

      allow(product).to receive(:broadcast_remove_to)

      product.archive!

      expect(product).to have_received(:broadcast_remove_to).with(user, "care_products", target: "care_product_#{product.id}")
    end

    it "broadcasts remove when product is soft deleted" do
      product = create(:care_product, user: user, stock_quantity: 0)

      allow(product).to receive(:broadcast_remove_to)

      product.soft_delete!

      expect(product).to have_received(:broadcast_remove_to).with(user, "care_products", target: "care_product_#{product.id}")
    end

    it "broadcasts append when archived product is restored" do
      product = create(:care_product, user: user, stock_quantity: 0, archived_at: 1.day.ago)

      allow(product).to receive(:broadcast_append_to)

      product.restore!

      expect(product).to have_received(:broadcast_append_to).with(user, "care_products",
        target: "care_products", partial: "care_products/care_product", locals: { care_product: product })
    end

    it "broadcasts remove to user care products stream on destroy" do
      product = create(:care_product, user: user)

      allow(product).to receive(:broadcast_remove_to)

      product.destroy!

      expect(product).to have_received(:broadcast_remove_to).with(user, "care_products", target: "care_product_#{product.id}")
    end
  end
end

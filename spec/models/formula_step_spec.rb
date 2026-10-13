require "rails_helper"

RSpec.describe FormulaStep do
  let(:formula_step) { build(:formula_step) }

  describe "associations" do
    it { is_expected.to belong_to(:service_note) }
    it { is_expected.to have_many(:formula_ingredients).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:section) }

    it "rejects unsupported sections" do
      formula_step.section = "invalid"

      expect(formula_step).not_to be_valid
      expect(formula_step.errors[:section]).to be_present
    end
  end

  describe "before_validation normalize_values" do
    context "when oxidant is blank" do
      [ "", nil, [] ].each do |value|
        it "normalizes #{value.inspect} to nil" do
          formula_step.oxidant = value

          formula_step.valid?

          expect(formula_step.oxidant).to be_nil
        end
      end
    end

    context "when oxidant contains valid data" do
      it "parses JSON object into an array" do
        formula_step.oxidant = { "service_id" => 1 }.to_json

        formula_step.valid?

        expect(formula_step.oxidant).to eq([ { "service_id" => 1 } ])
      end

      it "wraps oxidant hash in an array" do
        data = { "service_id" => 1 }
        formula_step.oxidant = data

        formula_step.valid?

        expect(formula_step.oxidant).to eq([ data ])
      end

      it "preserves oxidant array" do
        data = [ { "service_id" => 1 } ]
        formula_step.oxidant = data

        formula_step.valid?

        expect(formula_step.oxidant).to eq(data)
      end

      it "parses JSON array" do
        data = [ { "service_id" => 1 } ]
        formula_step.oxidant = data.to_json

        formula_step.valid?

        expect(formula_step.oxidant).to eq(data)
      end
    end

    context "when oxidant contains invalid data" do
      [ "{invalid", 123 ].each do |value|
        it "normalizes #{value.inspect} to nil" do
          formula_step.oxidant = value

          formula_step.valid?

          expect(formula_step.oxidant).to be_nil
        end
      end
    end

    context "when time is blank" do
      [ "", nil ].each do |value|
        it "normalizes #{value.inspect} to zero" do
          formula_step.time = value

          formula_step.valid?

          expect(formula_step.time).to eq(0)
        end
      end
    end

    context "when time is present" do
      it "preserves positive time" do
        formula_step.time = 35

        formula_step.valid?

        expect(formula_step.time).to eq(35)
      end

      it "preserves zero" do
        formula_step.time = 0

        formula_step.valid?

        expect(formula_step.time).to eq(0)
      end
    end
  end

  describe "#clear_oxidant!" do
    let(:formula_step) { create(:formula_step, oxidant: [ { "service_id" => 1 } ]) }

    it "clears oxidant" do
      formula_step.clear_oxidant!

      expect(formula_step.reload.oxidant).to be_nil
    end
  end

  describe "#clear_time!" do
    let(:formula_step) { create(:formula_step, time: 30) }

    it "resets time to zero" do
      formula_step.clear_time!

      expect(formula_step.reload.time).to eq(0)
    end
  end

  describe "time validation" do
    it "rejects negative time" do
      formula_step.time = -5

      expect(formula_step).not_to be_valid
      expect(formula_step.errors[:time]).to be_present
    end

    it "accepts zero" do
      formula_step.time = 0

      expect(formula_step).to be_valid
    end

    it "accepts positive time" do
      formula_step.time = 35

      expect(formula_step).to be_valid
    end

    it "persists zero when time is blank" do
      formula_step = build(:formula_step, service_note: create(:service_note))
      formula_step.time = ""
      formula_step.save!

      expect(formula_step.reload.time).to eq(0)
    end
  end

  describe "nested attributes" do
    it "rejects ingredient when shade and amount are blank" do
      formula_step.assign_attributes(formula_ingredients_attributes: [ { shade: "", amount: "" } ])

      expect(formula_step.formula_ingredients).to be_empty
    end

    it "accepts ingredient when shade is present" do
      formula_step.assign_attributes(formula_ingredients_attributes: [ { shade: "7.1", amount: "" } ])

      expect(formula_step.formula_ingredients.size).to eq(1)
    end

    it "accepts ingredient when amount is present" do
      formula_step.assign_attributes(formula_ingredients_attributes: [ { shade: "", amount: "20" } ])

      expect(formula_step.formula_ingredients.size).to eq(1)
    end
  end

  describe "#oxidant_product" do
    it "returns nil when product ID is absent" do
      formula_step.oxidant = { "amount" => 10 }

      expect(formula_step.oxidant_product).to be_nil
    end

    it "returns product by formula_product_id" do
      product = create(:formula_product, :oxidant)
      formula_step.oxidant = { "formula_product_id" => product.id }

      expect(formula_step.oxidant_product).to eq(product)
    end

    it "returns product by legacy service_id" do
      product = create(:formula_product, :oxidant)
      formula_step.oxidant = { "service_id" => product.id }

      expect(formula_step.oxidant_product).to eq(product)
    end

    it "returns nil when product does not exist" do
      formula_step.oxidant = { "formula_product_id" => -1 }

      expect(formula_step.oxidant_product).to be_nil
    end
  end

  describe "#oxidant_data" do
    it "returns empty array when oxidant is blank" do
      formula_step.oxidant = nil

      expect(formula_step.oxidant_data).to eq([])
    end

    it "parses JSON object" do
      formula_step.oxidant = { "service_id" => 1, "amount" => 10 }.to_json

      expect(formula_step.oxidant_data).to eq([ { "service_id" => 1, "amount" => 10 } ])
    end

    it "wraps oxidant hash in an array" do
      data = { "service_id" => 1, "amount" => 10 }
      formula_step.oxidant = data

      expect(formula_step.oxidant_data).to eq([ data ])
    end

    it "returns empty array for invalid JSON" do
      formula_step.oxidant = "{invalid"

      expect(formula_step.oxidant_data).to eq([])
    end

    it "returns empty array for unsupported type" do
      formula_step.oxidant = 123

      expect(formula_step.oxidant_data).to eq([])
    end

    it "returns empty array when product ID is missing" do
      formula_step.oxidant = { "amount" => 10 }

      expect(formula_step.oxidant_data).to eq([])
    end

    it "preserves oxidant array" do
      data = [ { "service_id" => 1, "amount" => 10 } ]
      formula_step.oxidant = data

      expect(formula_step.oxidant_data).to eq(data)
    end

    it "parses JSON array" do
      data = [ { "service_id" => 1, "amount" => 10 } ]
      formula_step.oxidant = data.to_json

      expect(formula_step.oxidant_data).to eq(data)
    end

    it "filters entries without product IDs" do
      data = [ { "service_id" => 1, "amount" => 10 }, { "amount" => 20 } ]

      formula_step.oxidant = data

      expect(formula_step.oxidant_data).to eq([ data.first ])
    end

    it "supports formula_product_id" do
      data = [ { "formula_product_id" => 1, "amount" => 10 } ]
      formula_step.oxidant = data

      expect(formula_step.oxidant_data).to eq(data)
    end
  end

  describe "#oxidant_amount" do
    it "returns total amount as float" do
      formula_step.oxidant = { "service_id" => 1, "amount" => "15" }

      expect(formula_step.oxidant_amount).to eq(15.0)
    end

    it "sums amounts from multiple oxidants" do
      formula_step.oxidant = [ { "service_id" => 1, "amount" => 10 }, { "service_id" => 2, "amount" => 15 } ]

      expect(formula_step.oxidant_amount).to eq(25.0)
    end

    it "returns zero when oxidant is blank" do
      formula_step.oxidant = nil

      expect(formula_step.oxidant_amount).to eq(0.0)
    end
  end

  describe "#oxidant_price" do
    it "returns total oxidant price" do
      formula_step.oxidant = { "service_id" => 1, "amount" => 10, "price" => "7.5" }

      expect(formula_step.oxidant_price).to eq(75.0)
    end
  end

  describe "#oxidant_ratio" do
    it "returns first oxidant ratio" do
      formula_step.oxidant = { "service_id" => 1, "ratio" => "1:2" }

      expect(formula_step.oxidant_ratio).to eq("1:2")
    end

    it "returns nil when oxidant is blank" do
      formula_step.oxidant = nil

      expect(formula_step.oxidant_ratio).to be_nil
    end
  end

  describe "#oxidant_total_price" do
    it "calculates total oxidant price" do
      formula_step.oxidant = { "service_id" => 1, "price" => 5, "amount" => 10 }

      expect(formula_step.oxidant_total_price).to eq(50.0)
    end

    it "sums prices from multiple oxidants" do
      formula_step.oxidant = [
        { "service_id" => 1, "price" => 5, "amount" => 10 },
        { "service_id" => 2, "price" => 3, "amount" => 20 }
      ]

      expect(formula_step.oxidant_total_price).to eq(110.0)
    end

    it "returns zero when oxidant is blank" do
      formula_step.oxidant = nil

      expect(formula_step.oxidant_total_price).to eq(0.0)
    end
  end

  describe "#colors_total_price" do
    it "returns total price of formula ingredients" do
      ingredient1 = build(:formula_ingredient, formula_step: formula_step)
      ingredient2 = build(:formula_ingredient, formula_step: formula_step)

      allow(ingredient1).to receive(:total_price).and_return(15)
      allow(ingredient2).to receive(:total_price).and_return(25)

      formula_step.formula_ingredients = [ ingredient1, ingredient2 ]

      expect(formula_step.colors_total_price).to eq(40)
    end

    it "returns zero when there are no ingredients" do
      expect(formula_step.colors_total_price).to eq(0)
    end
  end
end

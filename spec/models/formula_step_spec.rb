require "rails_helper"

RSpec.describe FormulaStep do
  describe "associations" do
    it { is_expected.to belong_to(:service_note) }
    it { is_expected.to have_many(:formula_ingredients).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:section) }
  end

  describe "callbacks" do
    describe "before_validation normalize_values" do
      let(:formula_step) { build(:formula_step, oxidant: "", time: "") }

      it "converts blank oxidant to nil" do
        formula_step.valid?
        expect(formula_step.oxidant).to be_nil
      end

      it "converts blank time to nil" do
        formula_step.valid?
        expect(formula_step.time).to be_nil
      end
    end
  end

  describe "#clear_oxidant!" do
    let(:formula_step) { create(:formula_step, oxidant: "6%") }

    it "sets oxidant to nil" do
      formula_step.clear_oxidant!
      expect(formula_step.reload.oxidant).to be_nil
    end
  end

  describe "#clear_time!" do
    let(:formula_step) { create(:formula_step, time: 30) }

    it "sets time to nil" do
      formula_step.clear_time!
      expect(formula_step.reload.time).to be_nil
    end
  end

  describe "nested attributes" do
    it "rejects formula_ingredient when shade and amount blank" do
      formula_step = described_class.new(
        section: "roots",
        service_note: create(:service_note),
        formula_ingredients_attributes: [
          {
            shade: "",
            amount: ""
          }
        ]
      )

      expect(formula_step.formula_ingredients).to be_empty
    end

    it "accepts formula_ingredient when shade present" do
      formula_step = described_class.new(
        section: "roots",
        service_note: create(:service_note),
        formula_ingredients_attributes: [
          {
            shade: "7.1",
            amount: ""
          }
        ]
      )

      expect(formula_step.formula_ingredients.size).to eq(1)
    end
  end

  describe "#oxidant_product" do
    it "returns nil when service_id absent" do
      formula_step = build(
        :formula_step,
        oxidant: {}
      )

      expect(formula_step.oxidant_product).to be_nil
    end

    it "returns formula product by formula_product_id" do
      product = create(:formula_product, :oxidant)

      formula_step = build(
        :formula_step,
        oxidant: {
          "formula_product_id" => product.id
        }
      )

      expect(formula_step.oxidant_product).to eq(product)
    end
  end

  describe "#oxidant_data" do
    it "returns empty array when oxidant blank" do
      formula_step = build(
        :formula_step,
        oxidant: nil
      )

      expect(formula_step.oxidant_data).to eq([])
    end

    it "parses oxidant json string" do
      formula_step = build(
        :formula_step,
        oxidant: {
          "service_id" => 1,
          "amount" => 10
        }.to_json
      )

      expect(formula_step.oxidant_data).to eq(
        [
          {
            "service_id" => 1,
            "amount" => 10
          }
        ]
      )
    end

    it "returns array with oxidant hash" do
      data = {
        "service_id" => 1,
        "amount" => 10
      }

      formula_step = build(
        :formula_step,
        oxidant: data
      )

      expect(formula_step.oxidant_data).to eq([ data ])
    end

    it "returns empty array for invalid json string" do
      formula_step = build(
        :formula_step,
        oxidant: "{invalid"
      )

      expect(formula_step.oxidant_data).to eq([])
    end

    it "returns empty array for unsupported oxidant type" do
      formula_step = build(
        :formula_step,
        oxidant: 123
      )

      expect(formula_step.oxidant_data).to eq([])
    end

    it "returns empty array when service_id missing" do
      formula_step = build(
        :formula_step,
        oxidant: {
          "amount" => 10
        }
      )

      expect(formula_step.oxidant_data).to eq([])
    end

    it "returns array oxidant as is" do
      data = [
        {
          "service_id" => 1,
          "amount" => 10
        }
      ]

      formula_step = build(
        :formula_step,
        oxidant: data
      )

      expect(formula_step.oxidant_data).to eq(data)
    end

    it "parses oxidant json array string" do
      data = [
        {
          "service_id" => 1,
          "amount" => 10
        }
      ]

      formula_step = build(
        :formula_step,
        oxidant: data.to_json
      )

      expect(formula_step.oxidant_data).to eq(data)
    end
  end

  describe "#oxidant_amount" do
    it "returns oxidant amount as float" do
      formula_step = build(
        :formula_step,
        oxidant: {
          "service_id" => 1,
          "amount" => "15"
        }
      )

      expect(formula_step.oxidant_amount).to eq(15.0)
    end
  end

  describe "#oxidant_price" do
    it "returns oxidant price as float" do
      formula_step = build(
        :formula_step,
        oxidant: {
          "service_id" => 1,
          "amount" => 10,
          "price" => "7.5"
        }
      )

      expect(formula_step.oxidant_price).to eq(75.0)
    end
  end

  describe "#oxidant_ratio" do
    it "returns oxidant ratio" do
      formula_step = build(
        :formula_step,
        oxidant: {
          "service_id" => 1,
          "ratio" => "1:2"
        }
      )

      expect(formula_step.oxidant_ratio).to eq("1:2")
    end

    it "returns nil when oxidant is empty" do
      formula_step = build(
        :formula_step,
        oxidant: nil
      )

      expect(formula_step.oxidant_ratio).to be_nil
    end
  end

  describe "#oxidant_total_price" do
    it "returns oxidant total price" do
      formula_step = build(
        :formula_step,
        oxidant: {
          "service_id" => 1,
          "price" => 5,
          "amount" => 10
        }
      )

      expect(formula_step.oxidant_total_price).to eq(50.0)
    end
  end

  describe "#colors_total_price" do
    it "returns total price of formula ingredients" do
      formula_step = create(:formula_step)

      ingredient1 = build(
        :formula_ingredient,
        formula_step: formula_step
      )

      ingredient2 = build(
        :formula_ingredient,
        formula_step: formula_step
      )

      allow(ingredient1).to receive(:total_price).and_return(15)
      allow(ingredient2).to receive(:total_price).and_return(25)

      formula_step.formula_ingredients = [
        ingredient1,
        ingredient2
      ]

      expect(formula_step.colors_total_price).to eq(40)
    end
  end

  describe "before_validation normalize_values" do
    it "parses oxidant json string into hash" do
      formula_step = build(
        :formula_step,
        oxidant: {
          "service_id" => 1
        }.to_json
      )

      formula_step.valid?

      expect(formula_step.oxidant).to eq(
        [
          { "service_id"=>1 }
        ]
      )
    end

    it "keeps array of oxidant hashes unchanged" do
      data = {
        "service_id" => 1
      }

      formula_step = build(
        :formula_step,
        oxidant: data
      )

      formula_step.valid?

      expect(formula_step.oxidant).to eq([ data ])
    end

    it "sets oxidant nil for invalid json" do
      formula_step = build(
        :formula_step,
        oxidant: "{invalid"
      )

      formula_step.valid?

      expect(formula_step.oxidant).to be_nil
    end

    it "sets oxidant nil when blank" do
      formula_step = build(
        :formula_step,
        oxidant: ""
      )

      formula_step.valid?

      expect(formula_step.oxidant).to be_nil
    end

    it "sets time nil when blank" do
      formula_step = build(
        :formula_step,
        time: ""
      )

      formula_step.valid?

      expect(formula_step.time).to be_nil
    end

    it "keeps oxidant array unchanged" do
      data = [
        {
          "service_id" => 1
        }
      ]

      formula_step = build(
        :formula_step,
        oxidant: data
      )

      formula_step.valid?

      expect(formula_step.oxidant).to eq(data)
    end

    it "sets oxidant nil for unsupported type" do
      formula_step = build(
        :formula_step,
        oxidant: 123
      )

      formula_step.valid?

      expect(formula_step.oxidant).to be_nil
    end
  end
end

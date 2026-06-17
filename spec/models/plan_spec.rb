require "rails_helper"

RSpec.describe Plan, type: :model do
  let(:account) { create(:account) }

  before { set_tenant(account) }

  it { should validate_presence_of(:name) }
  it { should validate_inclusion_of(:pricing_model).in_array(Plan::PRICING_MODELS) }

  describe "#calculate_price" do
    let(:currency) { create(:currency, account: account) }

    context "flat" do
      let(:plan) { create(:plan, account: account, price_cents: 19_700) }

      before { create(:plan_price, plan: plan, currency: currency, amount_cents: 19_700) }

      it "retorna o preço fixo independente da quantidade" do
        expect(plan.calculate_price(1, currency)).to eq(19_700)
        expect(plan.calculate_price(10, currency)).to eq(19_700)
      end
    end

    context "per_unit" do
      let(:plan) { create(:plan, account: account, pricing_model: "per_unit", price_cents: 4990) }

      before { create(:plan_price, plan: plan, currency: currency, amount_cents: 4990) }

      it "multiplica o preço pela quantidade" do
        expect(plan.calculate_price(3, currency)).to eq(14_970)
        expect(plan.calculate_price(10, currency)).to eq(49_900)
      end
    end

    context "volume" do
      let(:plan) { create(:plan, account: account, pricing_model: "volume", price_cents: 0) }

      before do
        create(:plan_pricing_tier, plan: plan, currency: currency,
               from_unit: 1, to_unit: 5,   unit_amount_cents: 4990, position: 0)
        create(:plan_pricing_tier, plan: plan, currency: currency,
               from_unit: 6, to_unit: nil, unit_amount_cents: 3990, position: 1)
      end

      it "aplica preço da faixa para todas as unidades" do
        expect(plan.calculate_price(3, currency)).to eq(14_970)  # 3 × 4990
        expect(plan.calculate_price(8, currency)).to eq(31_920)  # 8 × 3990 (faixa 2)
      end
    end
  end

  describe "#archive!" do
    it "desativa e define archived_at" do
      plan = create(:plan, account: account)
      plan.archive!
      expect(plan.active).to be false
      expect(plan.archived_at).not_to be_nil
    end
  end
end

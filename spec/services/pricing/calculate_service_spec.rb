require "rails_helper"

RSpec.describe Pricing::CalculateService do
  let(:account)  { create(:account) }
  let(:currency) { create(:currency, account: account) }
  let(:customer) { create(:customer, account: account) }

  before { set_tenant(account) }

  describe "modelo flat" do
    let(:plan) { create(:plan, account: account, pricing_model: "flat") }

    before { create(:plan_price, plan: plan, currency: currency, amount_cents: 19700) }

    it "retorna preço fixo" do
      result = described_class.call(plan: plan, customer: customer, currency: currency)
      expect(result.amount_cents).to eq(19700)
    end
  end

  describe "modelo per_unit" do
    let(:lt) { create(:license_type, account: account) }
    let(:plan) do
      create(:plan, account: account, pricing_model: "per_unit",
             pricing_license_type: lt)
    end

    before { create(:plan_price, plan: plan, currency: currency, amount_cents: 4990) }

    it "calcula preço pela quantidade de licenças usadas" do
      customer.metadata["license_usage"] = { lt.key => 5 }
      customer.save!
      result = described_class.call(plan: plan, customer: customer, currency: currency)
      expect(result.amount_cents).to eq(24950)  # 5 × 4990
      expect(result.quantity).to eq(5)
    end
  end

  describe "modelo volume" do
    let(:lt) { create(:license_type, account: account) }
    let(:plan) do
      create(:plan, account: account, pricing_model: "volume",
             pricing_license_type: lt)
    end

    before do
      create(:plan_pricing_tier, plan: plan, currency: currency,
             from_unit: 1,  to_unit: 5,   unit_amount_cents: 4990, position: 0)
      create(:plan_pricing_tier, plan: plan, currency: currency,
             from_unit: 6,  to_unit: 10,  unit_amount_cents: 4590, position: 1)
      create(:plan_pricing_tier, plan: plan, currency: currency,
             from_unit: 11, to_unit: nil, unit_amount_cents: 3990, position: 2)
    end

    it "aplica faixa 1 para 3 unidades" do
      customer.metadata["license_usage"] = { lt.key => 3 }
      customer.save!
      result = described_class.call(plan: plan, customer: customer, currency: currency)
      expect(result.amount_cents).to eq(14970)  # 3 × 4990
    end

    it "aplica faixa 2 para 8 unidades (preço da faixa para TODAS)" do
      customer.metadata["license_usage"] = { lt.key => 8 }
      customer.save!
      result = described_class.call(plan: plan, customer: customer, currency: currency)
      expect(result.amount_cents).to eq(36720)  # 8 × 4590
    end

    it "aplica faixa ilimitada para 15 unidades" do
      customer.metadata["license_usage"] = { lt.key => 15 }
      customer.save!
      result = described_class.call(plan: plan, customer: customer, currency: currency)
      expect(result.amount_cents).to eq(59850)  # 15 × 3990
    end
  end
end

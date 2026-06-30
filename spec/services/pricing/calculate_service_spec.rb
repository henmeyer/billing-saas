require "rails_helper"

RSpec.describe Pricing::CalculateService do
  let(:account)  { create(:account) }
  let(:currency) { create(:currency, account: account) }
  let(:customer) { create(:customer, account: account) }

  before { set_tenant(account) }

  describe "modelo flat" do
    let(:plan) { create(:plan, account: account, pricing_model: "flat") }

    before { create(:plan_price, plan: plan, currency: currency, amount_cents: 19_700) }

    it "retorna preço fixo" do
      result = described_class.call(plan: plan, customer: customer, currency: currency)
      expect(result.amount_cents).to eq(19_700)
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
      expect(result.amount_cents).to eq(24_950)  # 5 × 4990
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
      expect(result.amount_cents).to eq(14_970)  # 3 × 4990
    end

    it "aplica faixa 2 para 8 unidades (preço da faixa para TODAS)" do
      customer.metadata["license_usage"] = { lt.key => 8 }
      customer.save!
      result = described_class.call(plan: plan, customer: customer, currency: currency)
      expect(result.amount_cents).to eq(36_720)  # 8 × 4590
    end

    it "aplica faixa ilimitada para 15 unidades" do
      customer.metadata["license_usage"] = { lt.key => 15 }
      customer.save!
      result = described_class.call(plan: plan, customer: customer, currency: currency)
      expect(result.amount_cents).to eq(59_850)  # 15 × 3990
    end
  end

  describe "product_packs (pacotes de produto recorrentes)" do
    let(:plan) { create(:plan, account: account, pricing_model: "flat") }
    let(:credit_type) { create(:credit_type, account: account) }
    let(:product) do
      p = create(:product, account: account, product_type: "credit_pack",
                 pricing_model: "per_unit", credit_type: credit_type, credit_quantity: 1000)
      create(:product_price, product: p, currency: currency, amount_cents: 5_000)
      p
    end

    before { create(:plan_price, plan: plan, currency: currency, amount_cents: 19_700) }

    it "soma o custo dos packs ao valor base na renovação" do
      result = described_class.call(
        plan: plan, customer: customer, currency: currency,
        product_packs: { product.id.to_s => 2 }
      )

      expect(result.amount_cents).to eq(19_700 + 10_000) # base + 2 × 5000
      pack = result.product_packs_breakdown.first
      expect(pack[:product_id]).to eq(product.id)
      expect(pack[:quantity]).to eq(2)
      expect(pack[:total_credits]).to eq(2000)
      expect(pack[:cost_cents]).to eq(10_000)
    end

    it "ignora packs com quantidade zero ou produto inexistente" do
      result = described_class.call(
        plan: plan, customer: customer, currency: currency,
        product_packs: { product.id.to_s => 0, "999999" => 3 }
      )

      expect(result.amount_cents).to eq(19_700)
      expect(result.product_packs_breakdown).to be_empty
    end
  end
end

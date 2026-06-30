require "rails_helper"

RSpec.describe Subscriptions::PlanChangeService do
  let(:account)     { create(:account) }
  let(:currency)    { create(:currency, account: account, code: "BRL", default: true) }
  let(:customer)    { create(:customer, account: account, currency: currency) }
  let(:integration) { create(:integration, account: account) }
  let(:current_plan) { create(:plan, account: account, name: "Starter") }

  let(:subscription) do
    create(:subscription, :asaas,
           customer:             customer,
           plan:                 current_plan,
           integration:          integration,
           status:               "active",
           base_price_cents:     10_000,
           current_period_start: 15.days.ago,
           current_period_end:   15.days.from_now)
  end

  before { ActsAsTenant.current_tenant = account }
  after  { ActsAsTenant.current_tenant = nil }

  def plan_with_price(name, cents)
    p = create(:plan, account: account, name: name)
    create(:plan_price, plan: p, currency: currency, amount_cents: cents)
    p
  end

  describe "upgrade (plano mais caro)" do
    let(:new_plan) { plan_with_price("Pro", 20_000) }
    let(:adapter)  { instance_double(Gateways::AsaasAdapter) }

    before do
      allow(Gateways::Base).to receive(:for).with("asaas").and_return(adapter)
      allow(adapter).to receive(:create_charge).and_return(
        { "id" => "pay_upg_1", "redirect_url" => "https://pay/abc" }
      )
    end

    it "cria charge plan_change com a diferença pró-rata dos dias restantes" do
      result = described_class.call(subscription: subscription, new_plan: new_plan, changed_by: customer)

      expect(result.type).to eq(:upgrade)
      expect(result.prorated_cents).to eq(5_000) # (20000-10000) × 15/30

      charge = result.charge
      expect(charge.charge_type).to eq("plan_change")
      expect(charge.status).to eq("pending")
      expect(charge.amount_cents).to eq(5_000)
      expect(charge.charge_data["plan_change"]["new_plan_id"]).to eq(new_plan.id)
      expect(charge.redirect_url).to eq("https://pay/abc")
    end

    it "não altera o plano da assinatura ainda" do
      described_class.call(subscription: subscription, new_plan: new_plan, changed_by: customer)
      expect(subscription.reload.plan_id).to eq(current_plan.id)
    end
  end

  describe "downgrade (plano mais barato)" do
    let(:new_plan) { plan_with_price("Basic", 5_000) }

    it "agenda a troca para o fim do período sem cobrança" do
      expect(Gateways::Base).not_to receive(:for)

      result = described_class.call(subscription: subscription, new_plan: new_plan, changed_by: customer)

      expect(result.type).to eq(:downgrade)
      scheduled = subscription.reload.metadata["scheduled_plan_change"]
      expect(scheduled["plan_id"]).to eq(new_plan.id)
      expect(scheduled["effective_at"]).to be_present
      expect(subscription.charges.where(charge_type: "plan_change")).to be_empty
    end
  end

  describe "fluxo uniforme entre gateways" do
    %w[asaas stripe dlocal_go].each do |gw|
      it "cria charge plan_change para #{gw} no upgrade" do
        sub = create(:subscription,
                     customer: customer, plan: current_plan, integration: create(:integration, account: account),
                     gateway: gw, status: "active", base_price_cents: 10_000,
                     current_period_start: 10.days.ago, current_period_end: 20.days.from_now)
        new_plan = plan_with_price("Pro #{gw}", 40_000)

        adapter = instance_double("Gateways::#{gw.camelize}Adapter")
        allow(Gateways::Base).to receive(:for).with(gw).and_return(adapter)
        allow(adapter).to receive(:create_charge).and_return({ "id" => "c_#{gw}", "redirect_url" => "u" })

        result = described_class.call(subscription: sub, new_plan: new_plan, changed_by: customer)

        expect(result.type).to eq(:upgrade)
        expect(result.charge.gateway).to eq(gw)
        expect(result.charge.charge_type).to eq("plan_change")
      end
    end
  end
end

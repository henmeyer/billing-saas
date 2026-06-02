require "rails_helper"

RSpec.describe Dashboard::StatsService do
  let(:account) { create(:account) }
  let(:plan)    { create(:plan, account: account, price_cents: 9900) }

  before { ActsAsTenant.current_tenant = account }
  after  { ActsAsTenant.current_tenant = nil }

  subject(:stats) { described_class.call(account) }

  describe "#call" do
    context "com clientes e assinaturas ativas" do
      let!(:customer1) { create(:customer, account: account, status: "active") }
      let!(:customer2) { create(:customer, account: account, status: "active") }
      let!(:sub1) { create(:subscription, customer: customer1, plan: plan) }
      let!(:sub2) { create(:subscription, customer: customer2, plan: plan) }

      it "calcula MRR corretamente" do
        expect(stats[:mrr]).to eq(198.0)
      end

      it "calcula ARR como 12x MRR" do
        expect(stats[:arr]).to eq(stats[:mrr] * 12)
      end

      it "conta clientes ativos" do
        expect(stats[:active_customers]).to eq(2)
      end
    end

    context "sem dados" do
      it "retorna zeros" do
        expect(stats[:mrr]).to eq(0.0)
        expect(stats[:active_customers]).to eq(0)
        expect(stats[:past_due]).to eq(0)
      end
    end

    it "retorna todas as chaves esperadas" do
      expect(stats.keys).to include(
        :mrr, :arr, :active_customers, :churned_this_month,
        :past_due, :at_risk, :revenue_this_month,
        :mrr_by_plan, :recent_charges, :credits_depleted
      )
    end
  end
end

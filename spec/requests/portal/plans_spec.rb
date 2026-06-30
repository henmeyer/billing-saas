require "rails_helper"
require "inertia_rails/rspec"

RSpec.describe "Portal::Plans", type: :request do
  let(:account)  { create(:account) }
  let(:currency) { create(:currency, account: account, code: "BRL", default: true) }
  let(:integration) do
    create(:integration, account: account, portal_config: { "allow_plan_change" => true })
  end
  let(:customer)     { create(:customer, account: account, currency: currency) }
  let(:current_plan) { create(:plan, account: account, name: "Starter") }
  let(:raw_token)    { "portal-plans-token" }

  let(:subscription) do
    create(:subscription, :asaas,
           customer:             customer,
           plan:                 current_plan,
           integration:          integration,
           status:               "active",
           base_price_cents:     10_000,
           current_period_start: 10.days.ago,
           current_period_end:   20.days.from_now)
  end

  before do
    ActsAsTenant.current_tenant = account
    create(:portal_session, customer: customer, integration: integration,
           token_digest: Digest::SHA256.hexdigest(raw_token))
    subscription
  end

  after { ActsAsTenant.current_tenant = nil }

  def plan_with_price(name, cents)
    p = create(:plan, account: account, name: name)
    create(:plan_price, plan: p, currency: currency, amount_cents: cents)
    p
  end

  describe "PUT /portal/:token/plans/:id" do
    context "upgrade" do
      let(:new_plan) { plan_with_price("Pro", 30_000) }
      let(:adapter)  { instance_double(Gateways::AsaasAdapter) }

      before do
        allow(Gateways::Base).to receive(:for).with("asaas").and_return(adapter)
        allow(adapter).to receive(:create_charge).and_return(
          { "id" => "pay_up_1", "redirect_url" => "https://pay/checkout" }
        )
      end

      it "redireciona para o checkout do gateway" do
        target = new_plan
        ActsAsTenant.with_tenant(nil) do
          put "/portal/#{raw_token}/plans/#{target.id}"
        end

        expect(response).to redirect_to("https://pay/checkout")
      end
    end

    context "downgrade" do
      let(:new_plan) { plan_with_price("Basic", 5_000) }

      it "agenda e volta ao dashboard com aviso" do
        target = new_plan
        ActsAsTenant.with_tenant(nil) do
          put "/portal/#{raw_token}/plans/#{target.id}"
        end

        expect(response).to redirect_to("/portal/#{raw_token}")
        ActsAsTenant.with_tenant(account) do
          expect(subscription.reload.metadata["scheduled_plan_change"]["plan_id"]).to eq(target.id)
        end
      end
    end
  end
end

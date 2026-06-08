require "rails_helper"

RSpec.describe Subscriptions::CreateService do
  let(:account)  { create(:account) }
  let(:customer) { create(:customer, account: account) }
  let(:plan)     { create(:plan, account: account, price_cents: 19700) }
  let(:currency) { create(:currency, account: account) }

  before do
    set_tenant(account)
    create(:plan_price, plan: plan, currency: currency, amount_cents: 19700)
    create(:payment_gateway, account: account, provider: "asaas")
  end

  context "com Asaas mockado" do
    before do
      stub_request(:post, /asaas\.com/)
        .to_return(
          status:  200,
          body:    { id: "cus_test", subscriptionId: "sub_test" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "cria subscription e subscription_period" do
      result = described_class.call(
        customer:    customer,
        plan_id:     plan.id,
        gateway:     "asaas",
        currency_id: currency.id
      )
      expect(result.success?).to be true
      expect(customer.subscriptions.count).to eq(1)
      expect(customer.subscriptions.first.subscription_periods.count).to eq(1)
    end

    it "dispara webhook subscription.activated" do
      expect(WebhookDispatchJob).to receive(:perform_later).with(
        customer, "subscription.activated", anything
      )
      described_class.call(
        customer:    customer,
        plan_id:     plan.id,
        gateway:     "asaas",
        currency_id: currency.id
      )
    end
  end
end

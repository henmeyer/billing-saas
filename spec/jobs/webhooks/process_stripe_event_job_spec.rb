require "rails_helper"

RSpec.describe Webhooks::ProcessStripeEventJob do
  let(:account)  { create(:account) }
  let(:customer) { create(:customer, account: account) }
  let(:plan)     { create(:plan, account: account) }
  let(:sub) do
    create(:subscription,
           customer:                customer,
           plan:                    plan,
           gateway_subscription_id: "sub_stripe_abc")
  end

  before { set_tenant(account) }
  after  { ActsAsTenant.current_tenant = nil }

  describe "payment_received" do
    let(:payload) do
      {
        "subscription" => sub.gateway_subscription_id,
        "charge"       => "ch_xyz",
        "amount_paid"  => 9900,
        "period_start" => 1.day.ago.to_i,
        "period_end"   => 29.days.from_now.to_i
      }
    end

    it "cria uma charge paid" do
      expect {
        described_class.perform_now("payment_received", payload)
      }.to change(Charge, :count).by(1)

      expect(Charge.last.status).to eq("paid")
      expect(Charge.last.gateway_charge_id).to eq("ch_xyz")
    end

    it "cria um subscription_period" do
      expect {
        described_class.perform_now("payment_received", payload)
      }.to change(SubscriptionPeriod, :count).by(1)
    end

    it "é idempotente" do
      described_class.perform_now("payment_received", payload)
      expect {
        described_class.perform_now("payment_received", payload)
      }.not_to change(Charge, :count)
    end
  end

  describe "payment_failed" do
    it "marca a subscription como past_due" do
      described_class.perform_now("payment_failed", {
                                    "subscription"  => sub.gateway_subscription_id,
                                    "amount_due"    => 9900,
                                    "attempt_count" => 1
                                  })
      expect(sub.reload.status).to eq("past_due")
    end
  end

  describe "subscription_cancelled" do
    it "cancela a subscription" do
      described_class.perform_now("subscription_cancelled", {
                                    "id" => sub.gateway_subscription_id
                                  })
      expect(sub.reload.status).to eq("cancelled")
    end
  end
end

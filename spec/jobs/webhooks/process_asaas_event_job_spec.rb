require "rails_helper"

RSpec.describe Webhooks::ProcessAsaasEventJob do
  let(:account)  { create(:account) }
  let(:customer) { create(:customer, account: account) }
  let(:plan)     { create(:plan, account: account) }
  let(:sub) do
    create(:subscription, :asaas,
      customer: customer,
      plan: plan,
      gateway_subscription_id: "sub_asaas_123"
    )
  end

  describe "payment_received" do
    let(:payload) do
      {
        "event"   => "PAYMENT_RECEIVED",
        "payment" => {
          "id"           => "pay_abc",
          "subscription" => sub.gateway_subscription_id,
          "value"        => 99.0,
          "dueDate"      => Date.today.to_s,
          "paymentDate"  => Date.today.to_s
        }
      }
    end

    it "cria uma charge com status paid" do
      expect {
        described_class.perform_now("payment_received", payload)
      }.to change(Charge, :count).by(1)

      charge = Charge.last
      expect(charge.status).to eq("paid")
      expect(charge.amount_cents).to eq(9900)
      expect(charge.gateway_charge_id).to eq("pay_abc")
    end

    it "atualiza o status da subscription para active" do
      described_class.perform_now("payment_received", payload)
      expect(sub.reload.status).to eq("active")
    end

    it "cria um subscription_period" do
      expect {
        described_class.perform_now("payment_received", payload)
      }.to change(SubscriptionPeriod, :count).by(1)
    end

    it "é idempotente — não duplica charge com mesmo gateway_charge_id" do
      described_class.perform_now("payment_received", payload)
      expect {
        described_class.perform_now("payment_received", payload)
      }.not_to change(Charge, :count)
    end
  end

  describe "payment_overdue" do
    it "marca a subscription como past_due" do
      described_class.perform_now("payment_overdue", {
        "payment" => { "subscription" => sub.gateway_subscription_id }
      })
      expect(sub.reload.status).to eq("past_due")
    end
  end

  describe "subscription_cancelled" do
    it "cancela a subscription" do
      described_class.perform_now("subscription_cancelled", {
        "subscription" => { "id" => sub.gateway_subscription_id }
      })
      expect(sub.reload.status).to eq("cancelled")
      expect(sub.reload.cancelled_at).to be_present
    end
  end

  describe "quando subscription não existe" do
    it "retorna sem erro" do
      expect {
        described_class.perform_now("payment_received", {
          "payment" => { "subscription" => "sub_inexistente" }
        })
      }.not_to raise_error
    end
  end
end

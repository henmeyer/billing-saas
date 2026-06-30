require "rails_helper"

# Garante que charges avulsas (produto/troca de plano) acionam o dispatcher
# de aplicação e NÃO disparam a lógica de renovação de assinatura.
RSpec.describe "Aplicação de charge avulsa via webhooks" do
  let(:account)     { create(:account) }
  let(:customer)    { create(:customer, account: account) }
  let(:plan)        { create(:plan, account: account) }
  let(:integration) { create(:integration, account: account) }

  before do
    set_tenant(account)
    allow(WebhookDispatchJob).to receive(:perform_later)
    allow(Charges::ApplyPaidChargeService).to receive(:call)
  end

  after { ActsAsTenant.current_tenant = nil }

  describe Webhooks::ProcessAsaasEventJob do
    let(:sub) do
      create(:subscription, :asaas,
             customer:                customer,
             plan:                    plan,
             integration:             integration,
             gateway_subscription_id: "sub_asaas_1",
             base_price_cents:        9900)
    end

    let!(:product_charge) do
      create(:charge, :pending,
             customer:          customer,
             subscription:      sub,
             gateway:           "asaas",
             gateway_charge_id: "pay_product_1",
             amount_cents:      5_000,
             charge_type:       "product",
             charge_data:       { "product_purchase" => { "product_type" => "credit_pack" } })
    end

    let(:payload) do
      { "payment" => { "id" => "pay_product_1", "subscription" => sub.gateway_subscription_id,
                       "value" => 50.0, "paymentDate" => Date.today.to_s } }
    end

    it "marca a charge como paga e aciona o dispatcher" do
      described_class.perform_now("payment_received", payload)

      expect(product_charge.reload.status).to eq("paid")
      expect(Charges::ApplyPaidChargeService).to have_received(:call).with(charge: product_charge)
    end

    it "não cria novo período de assinatura" do
      expect {
        described_class.perform_now("payment_received", payload)
      }.not_to change(SubscriptionPeriod, :count)
    end
  end

  describe Webhooks::ProcessDlocalGoEventJob do
    let(:sub) do
      create(:subscription, :dlocal_go,
             customer:                customer,
             plan:                    plan,
             integration:             integration,
             gateway_subscription_id: "sub_dlocal_1",
             base_price_cents:        9900)
    end

    let!(:product_charge) do
      create(:charge, :pending,
             customer:          customer,
             subscription:      sub,
             gateway:           "dlocal_go",
             gateway_charge_id: "dl_product_1",
             amount_cents:      5_000,
             charge_type:       "product",
             charge_data:       { "product_purchase" => { "product_type" => "credit_pack" } })
    end

    let(:payload) do
      { "id" => "dl_product_1", "order_id" => "charge_#{customer.id}_123", "amount" => 50.0 }
    end

    it "marca a charge como paga e aciona o dispatcher sem renovar" do
      expect {
        described_class.perform_now("payment_received", payload)
      }.not_to change(SubscriptionPeriod, :count)

      expect(product_charge.reload.status).to eq("paid")
      expect(Charges::ApplyPaidChargeService).to have_received(:call).with(charge: product_charge)
    end
  end
end

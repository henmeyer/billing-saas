require "rails_helper"

RSpec.describe Credits::CheckThresholdsService do
  let(:account)  { create(:account) }
  let(:customer) { create(:customer, account: account) }
  let(:plan)     { create(:plan, account: account) }
  let(:sub)      { create(:subscription, customer: customer, plan: plan) }
  let(:period)   { create(:subscription_period, subscription: sub) }
  let(:credit_type) { create(:credit_type, account: account) }
  let(:snapshot) do
    create(:credit_snapshot,
           subscription_period: period,
           credit_type:         credit_type,
           used:                used,
           limit:               1000)
  end

  before { ActsAsTenant.current_tenant = account }
  after  { ActsAsTenant.current_tenant = nil }

  subject { described_class.call(customer, snapshot) }

  context "quando uso abaixo de 80%" do
    let(:used) { 700 }

    it "não cria alertas" do
      expect { subject }.not_to change(CreditAlert, :count)
    end

    it "não enfileira webhooks" do
      expect(WebhookDispatchJob).not_to receive(:perform_later)
      subject
    end
  end

  context "quando uso atingiu 80%" do
    let(:used) { 800 }

    it "cria alerta de 80%" do
      expect { subject }.to change(CreditAlert, :count).by(1)
      expect(CreditAlert.last.threshold).to eq(80)
    end

    it "dispara webhook credits.threshold_reached" do
      expect(WebhookDispatchJob).to receive(:perform_later)
        .with(customer, "credits.threshold_reached", hash_including(threshold: 80))
      subject
    end
  end

  context "quando uso atingiu 100%" do
    let(:used) { 1000 }

    it "cria alertas de 80%, 95% e 100%" do
      expect { subject }.to change(CreditAlert, :count).by(3)
    end

    it "dispara webhook credits.depleted para o threshold 100" do
      expect(WebhookDispatchJob).to receive(:perform_later)
        .with(customer, "credits.threshold_reached", hash_including(threshold: 80))
      expect(WebhookDispatchJob).to receive(:perform_later)
        .with(customer, "credits.threshold_reached", hash_including(threshold: 95))
      expect(WebhookDispatchJob).to receive(:perform_later)
        .with(customer, "credits.depleted", hash_including(threshold: 100))
      subject
    end
  end

  context "quando o alerta já foi enviado no período" do
    let(:used) { 800 }

    before do
      create(:credit_alert,
             customer:     customer,
             credit_type:  credit_type,
             threshold:    80,
             period_start: sub.current_period_start)
    end

    it "não duplica o alerta" do
      expect { subject }.not_to change(CreditAlert, :count)
    end
  end
end

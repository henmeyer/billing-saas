require "rails_helper"

RSpec.describe Webhooks::ProcessDlocalGoEventJob do
  let(:account)     { create(:account) }
  let(:customer)    { create(:customer, account: account) }
  let(:integration) { create(:integration, account: account) }
  let(:plan)        { create(:plan, account: account) }

  let(:subscription) do
    create(:subscription, :dlocal_go,
      customer:    customer,
      plan:        plan,
      integration: integration,
      status:      "pending",
      started_at:  Time.current
    )
  end

  let(:payment_id) { "pay_#{SecureRandom.hex(8)}" }
  let(:order_id)   { "sub_#{customer.id}_#{Time.current.to_i}" }

  let(:payload) do
    {
      "id"       => payment_id,
      "order_id" => order_id,
      "amount"   => 197.0,
      "status"   => "PAID"
    }
  end

  before do
    set_tenant(account)
    subscription
    allow(WebhookDispatchJob).to receive(:perform_later)
  end

  after { ActsAsTenant.current_tenant = nil }

  describe "payment_received — primeiro pagamento (pending)" do
    let!(:existing_period) do
      create(:subscription_period,
        subscription: subscription,
        period_start: Time.current.beginning_of_day,
        period_end:   1.month.from_now.beginning_of_day,
        amount_cents: 0
      )
    end

    it "salva o checkout_id no gateway_data do customer" do
      described_class.perform_now("payment_received", payload)
      expect(customer.reload.gateway_data.dig("dlocal_go", "checkout_id")).to eq(payment_id)
    end

    it "cria uma charge com status paid e valor correto" do
      expect {
        described_class.perform_now("payment_received", payload)
      }.to change(Charge, :count).by(1)

      charge = Charge.last
      expect(charge.status).to eq("paid")
      expect(charge.amount_cents).to eq(19700)
      expect(charge.gateway_charge_id).to eq(payment_id)
    end

    it "ativa a assinatura" do
      described_class.perform_now("payment_received", payload)
      expect(subscription.reload.status).to eq("active")
    end

    it "atualiza o período existente sem criar um novo" do
      expect {
        described_class.perform_now("payment_received", payload)
      }.not_to change(SubscriptionPeriod, :count)

      expect(existing_period.reload.amount_cents).to eq(19700)
    end

    it "dispara subscription.activated com dados do plano" do
      described_class.perform_now("payment_received", payload)

      expect(WebhookDispatchJob).to have_received(:perform_later).with(
        customer,
        "subscription.activated",
        hash_including(plan: hash_including(id: plan.id, name: plan.name))
      )
    end

    it "não dispara payment.received nem subscription.renewed" do
      described_class.perform_now("payment_received", payload)

      expect(WebhookDispatchJob).not_to have_received(:perform_later)
        .with(anything, "payment.received", anything)
      expect(WebhookDispatchJob).not_to have_received(:perform_later)
        .with(anything, "subscription.renewed", anything)
    end

    it "é idempotente — segunda chamada com mesmo payment_id não duplica charge" do
      described_class.perform_now("payment_received", payload)

      expect {
        described_class.perform_now("payment_received", payload)
      }.not_to change(Charge, :count)
    end
  end

  describe "payment_received — renovação (active)" do
    before do
      subscription.update!(
        status:               "active",
        current_period_start: 1.month.ago.beginning_of_day,
        current_period_end:   Time.current.beginning_of_day
      )
      create(:subscription_period,
        subscription: subscription,
        period_start: 1.month.ago.beginning_of_day,
        period_end:   Time.current.beginning_of_day
      )
    end

    let(:order_id) { "renew_#{customer.id}_#{Time.current.to_i}" }

    it "cria um novo subscription_period" do
      expect {
        described_class.perform_now("payment_received", payload)
      }.to change(SubscriptionPeriod, :count).by(1)
    end

    it "mantém a assinatura active" do
      described_class.perform_now("payment_received", payload)
      expect(subscription.reload.status).to eq("active")
    end

    it "dispara payment.received com valor" do
      described_class.perform_now("payment_received", payload)

      expect(WebhookDispatchJob).to have_received(:perform_later).with(
        customer,
        "payment.received",
        hash_including(amount_cents: 19700, gateway: "dlocal_go", charge_id: payment_id)
      )
    end

    it "dispara subscription.renewed com period_end" do
      described_class.perform_now("payment_received", payload)

      expect(WebhookDispatchJob).to have_received(:perform_later).with(
        customer,
        "subscription.renewed",
        hash_including(:period_end)
      )
    end

    it "não dispara subscription.activated" do
      described_class.perform_now("payment_received", payload)

      expect(WebhookDispatchJob).not_to have_received(:perform_later)
        .with(anything, "subscription.activated", anything)
    end
  end

  describe "payment_received — assinatura past_due que renova" do
    before { subscription.update!(status: "past_due") }

    let!(:existing_period) do
      create(:subscription_period, subscription: subscription,
        period_start: 1.month.ago.beginning_of_day,
        period_end:   1.day.ago.beginning_of_day)
    end

    it "ativa a assinatura e cria novo período" do
      expect {
        described_class.perform_now("payment_received", payload)
      }.to change(SubscriptionPeriod, :count).by(1)

      expect(subscription.reload.status).to eq("active")
    end
  end

  describe "payment_failed" do
    it "marca a subscription como past_due" do
      described_class.perform_now("payment_failed", payload)
      expect(subscription.reload.status).to eq("past_due")
    end

    it "dispara payment.failed com reason" do
      described_class.perform_now("payment_failed",
        payload.merge("status" => "REJECTED", "status_detail" => "Card declined"))

      expect(WebhookDispatchJob).to have_received(:perform_later).with(
        subscription.customer,
        "payment.failed",
        hash_including(gateway: "dlocal_go", reason: "Card declined")
      )
    end
  end

  describe "quando order_id não tem formato de subscription" do
    let(:order_id) { "charge_#{customer.id}_#{Time.current.to_i}" }

    it "não cria charge" do
      expect {
        described_class.perform_now("payment_received", payload)
      }.not_to change(Charge, :count)
    end

    it "não muda o status da subscription" do
      expect {
        described_class.perform_now("payment_received", payload)
      }.not_to change { subscription.reload.status }
    end
  end

  describe "quando order_id tem formato inválido" do
    let(:order_id) { "formato_invalido" }

    it "retorna sem levantar erro" do
      expect {
        described_class.perform_now("payment_received", payload)
      }.not_to raise_error
    end
  end

  describe "quando customer_id não existe" do
    let(:order_id) { "sub_999999_12345" }

    it "retorna sem levantar erro" do
      expect {
        described_class.perform_now("payment_received", payload)
      }.not_to raise_error
    end
  end
end

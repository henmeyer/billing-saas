require "rails_helper"

RSpec.describe Subscriptions::CreateService do
  let(:account)       { create(:account) }
  let(:customer)      { create(:customer, account: account) }
  let(:integration)   { create(:integration, account: account, active: true) }
  let(:plan)          { create(:plan, account: account) }
  let(:currency)      { create(:currency, account: account) }
  let(:credit_type)   { create(:credit_type, account: account) }
  let(:license_type)  { create(:license_type, account: account) }

  before do
    set_tenant(account)
    create(:plan_price, plan: plan, currency: currency, amount_cents: 19_700)
    create(:payment_gateway, account: account, provider: "asaas")
    create(:plan_credit,  plan: plan, credit_type: credit_type, quantity: 1000)
    create(:plan_license, plan: plan, license_type: license_type, quantity: 20)
    create(:plan_integration, plan: plan, integration: integration)
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

    it "cria subscription e subscription_period com integration_id" do
      result = described_class.call(
        customer:       customer,
        plan_id:        plan.id,
        gateway:        "asaas",
        integration_id: integration.id,
        currency_id:    currency.id
      )
      expect(result.success?).to be true
      expect(customer.subscriptions.count).to eq(1)
      expect(customer.subscriptions.first.integration_id).to eq(integration.id)
      expect(customer.subscriptions.first.subscription_periods.count).to eq(1)
    end

    it "salva base_price_cents e currency_code na subscription" do
      result = described_class.call(
        customer:       customer,
        plan_id:        plan.id,
        gateway:        "asaas",
        integration_id: integration.id,
        currency_id:    currency.id
      )
      sub = result.subscription
      expect(sub.base_price_cents).to eq(19_700)
      expect(sub.currency_code).to eq(currency.code)
    end

    it "salva amount_cents no subscription_period" do
      result = described_class.call(
        customer:       customer,
        plan_id:        plan.id,
        gateway:        "asaas",
        integration_id: integration.id,
        currency_id:    currency.id
      )
      period = result.subscription.subscription_periods.last
      expect(period.amount_cents).to eq(19_700)
      expect(period.base_amount_cents).to eq(19_700)
      expect(period.extras_amount_cents).to eq(0)
    end

    it "cria subscription_period_credits com base, extras e snapshot" do
      result = described_class.call(
        customer:       customer,
        plan_id:        plan.id,
        gateway:        "asaas",
        integration_id: integration.id,
        currency_id:    currency.id
      )
      period = result.subscription.subscription_periods.last

      spc = period.subscription_period_credits.find_by(credit_type: credit_type)
      expect(spc).to be_present
      expect(spc.base).to eq(1000)
      expect(spc.extras).to eq(0)
      expect(spc.quantity).to eq(1000)

      snapshot = period.credit_snapshots.find_by(credit_type: credit_type)
      expect(snapshot.limit).to eq(1000)
      expect(snapshot.used).to eq(0)
    end

    it "cria subscription_period_licenses" do
      result = described_class.call(
        customer:       customer,
        plan_id:        plan.id,
        gateway:        "asaas",
        integration_id: integration.id,
        currency_id:    currency.id
      )
      period = result.subscription.subscription_periods.last

      spl = period.subscription_period_licenses.find_by(license_type: license_type)
      expect(spl).to be_present
      expect(spl.quantity).to eq(20)
    end

    it "não dispara webhook subscription.activated (espera confirmação do pagamento)" do
      expect(WebhookDispatchJob).not_to receive(:perform_later).with(
        customer, "subscription.activated", anything
      )
      result = described_class.call(
        customer:       customer,
        plan_id:        plan.id,
        gateway:        "asaas",
        integration_id: integration.id,
        currency_id:    currency.id
      )
      expect(result.subscription.status).to eq("pending")
      expect(result.subscription.managed_by).to eq("billing")
    end
  end

  context "validação de integration_id" do
    it "retorna erro quando integração não existe" do
      result = described_class.call(
        customer:       customer,
        plan_id:        plan.id,
        gateway:        "asaas",
        integration_id: 0,
        currency_id:    currency.id
      )
      expect(result.success?).to be false
      expect(result.errors).to include("Integração não encontrada")
    end

    it "retorna erro quando integração está inativa" do
      inactive_integration = create(:integration, account: account, active: false)
      create(:plan_integration, plan: plan, integration: inactive_integration)

      result = described_class.call(
        customer:       customer,
        plan_id:        plan.id,
        gateway:        "asaas",
        integration_id: inactive_integration.id,
        currency_id:    currency.id
      )
      expect(result.success?).to be false
      expect(result.errors).to include("Integração não está ativa")
    end

    it "retorna erro quando plano não está vinculado à integração" do
      other_integration = create(:integration, account: account, active: true)

      result = described_class.call(
        customer:       customer,
        plan_id:        plan.id,
        gateway:        "asaas",
        integration_id: other_integration.id,
        currency_id:    currency.id
      )
      expect(result.success?).to be false
      expect(result.errors).to include("Plano não está disponível para esta integração")
    end

    it "retorna erro descritivo em race condition de unicidade" do
      # Simulate: first subscription created successfully
      stub_request(:post, /asaas\.com/)
        .to_return(
          status:  200,
          body:    { id: "cus_test", subscriptionId: "sub_test" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      described_class.call(
        customer:       customer,
        plan_id:        plan.id,
        gateway:        "asaas",
        integration_id: integration.id,
        currency_id:    currency.id
      )

      # Second attempt should fail with model validation
      result = described_class.call(
        customer:       customer,
        plan_id:        plan.id,
        gateway:        "asaas",
        integration_id: integration.id,
        currency_id:    currency.id
      )
      expect(result.success?).to be false
    end

    it "retorna erro descritivo quando RecordNotUnique é levantado" do
      stub_request(:post, /asaas\.com/)
        .to_return(
          status:  200,
          body:    { id: "cus_test", subscriptionId: "sub_test" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      # Stub the create! to raise RecordNotUnique to simulate race condition
      allow_any_instance_of(ActiveRecord::Associations::CollectionProxy).to receive(:create!).and_raise(
        ActiveRecord::RecordNotUnique.new("duplicate key value")
      )

      result = described_class.call(
        customer:       customer,
        plan_id:        plan.id,
        gateway:        "asaas",
        integration_id: integration.id,
        currency_id:    currency.id
      )
      expect(result.success?).to be false
      expect(result.errors).to include("Já existe assinatura ativa para este cliente nesta integração")
    end
  end

  context "Asaas billing-managed" do
    before do
      stub_request(:post, /asaas\.com/)
        .to_return(
          status:  200,
          body:    { id: "pay_first_123", status: "PENDING", invoiceUrl: "https://asaas.com/i/123", billingType: "PIX" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
      stub_request(:get, /asaas\.com/)
        .to_return(
          status:  200,
          body:    { encodedImage: "base64qr", payload: "pix-copy-paste" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "cria subscription com managed_by billing e status pending" do
      result = described_class.call(
        customer:       customer,
        plan_id:        plan.id,
        gateway:        "asaas",
        integration_id: integration.id,
        currency_id:    currency.id
      )
      expect(result.success?).to be true

      sub = result.subscription
      expect(sub.managed_by).to eq("billing")
      expect(sub.status).to eq("pending")
      expect(sub.gateway).to eq("asaas")
    end

    it "cria charge pendente com dados do Asaas" do
      result = described_class.call(
        customer:       customer,
        plan_id:        plan.id,
        gateway:        "asaas",
        integration_id: integration.id,
        currency_id:    currency.id
      )
      sub = result.subscription

      charge = sub.charges.first
      expect(charge).to be_present
      expect(charge.status).to eq("pending")
      expect(charge.gateway).to eq("asaas")
      expect(charge.charge_type).to eq("new_subscription")
      expect(charge.gateway_charge_id).to be_present
    end

    it "gateway_subscription_id segue formato sub_ID_TIMESTAMP" do
      result = described_class.call(
        customer:       customer,
        plan_id:        plan.id,
        gateway:        "asaas",
        integration_id: integration.id,
        currency_id:    currency.id
      )
      sub = result.subscription
      expect(sub.gateway_subscription_id).to match(/\Asub_\d+_\d+\z/)
    end
  end

  context "trial" do
    it "cria assinatura como trialing sem gateway" do
      result = described_class.call(
        customer:       customer,
        plan_id:        plan.id,
        integration_id: integration.id,
        currency_id:    currency.id,
        trial:          true
      )
      expect(result.success?).to be true

      sub = result.subscription
      expect(sub.status).to eq("trialing")
      expect(sub.gateway).to be_nil
      expect(sub.gateway_subscription_id).to be_nil
      expect(sub.trial_ends_at).to be_present
    end

    it "usa plan.trial_days para calcular trial_ends_at" do
      plan.update!(trial_days: 14)

      result = described_class.call(
        customer:       customer,
        plan_id:        plan.id,
        integration_id: integration.id,
        currency_id:    currency.id,
        trial:          true
      )

      expect(result.subscription.trial_ends_at).to be_within(1.minute).of(14.days.from_now.beginning_of_day)
    end

    it "usa 7 dias como padrão quando plan.trial_days é zero" do
      result = described_class.call(
        customer:       customer,
        plan_id:        plan.id,
        integration_id: integration.id,
        currency_id:    currency.id,
        trial:          true
      )

      expect(result.subscription.trial_ends_at).to be_within(1.minute).of(7.days.from_now.beginning_of_day)
    end

    it "cria período com amount_cents 0" do
      result = described_class.call(
        customer:       customer,
        plan_id:        plan.id,
        integration_id: integration.id,
        currency_id:    currency.id,
        trial:          true
      )

      period = result.subscription.subscription_periods.first
      expect(period.amount_cents).to eq(0)
      expect(period.base_amount_cents).to eq(0)
      expect(period.extras_amount_cents).to eq(0)
    end

    it "cria snapshots com os limites do plano" do
      result = described_class.call(
        customer:       customer,
        plan_id:        plan.id,
        integration_id: integration.id,
        currency_id:    currency.id,
        trial:          true
      )

      period = result.subscription.subscription_periods.first
      expect(period.credit_snapshots.count).to be > 0
      expect(period.credit_snapshots.first.limit).to eq(1000)
      expect(period.subscription_period_licenses.first.quantity).to eq(20)
    end

    it "não chama nenhum gateway de pagamento" do
      expect(Gateways::Base).not_to receive(:for)

      result = described_class.call(
        customer:       customer,
        plan_id:        plan.id,
        integration_id: integration.id,
        currency_id:    currency.id,
        trial:          true
      )
      expect(result.success?).to be true
    end
  end
end

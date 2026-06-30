require "rails_helper"

RSpec.describe Subscriptions::ApplyPlanChangeService do
  let(:account)     { create(:account) }
  let(:currency)    { create(:currency, account: account, code: "BRL", default: true) }
  let(:customer)    { create(:customer, account: account, currency: currency) }
  let(:integration) { create(:integration, account: account) }
  let(:credit_type) { create(:credit_type, account: account, key: "coins") }
  let(:old_plan)    { create(:plan, account: account, name: "Starter") }

  let(:new_plan) do
    p = create(:plan, account: account, name: "Pro")
    create(:plan_price, plan: p, currency: currency, amount_cents: 20_000)
    create(:plan_credit, plan: p, credit_type: credit_type, quantity: 5_000)
    p
  end

  before { ActsAsTenant.current_tenant = account }

  let(:subscription) do
    create(:subscription, :asaas,
           customer:             customer,
           plan:                 old_plan,
           integration:          integration,
           status:               "active",
           base_price_cents:     10_000,
           current_period_start: 10.days.ago,
           current_period_end:   20.days.from_now)
  end

  let!(:period) do
    create(:subscription_period, subscription: subscription,
           period_start: 10.days.ago, period_end: 20.days.from_now)
  end

  let(:charge) do
    create(:charge,
           customer:     customer,
           subscription: subscription,
           status:       "paid",
           charge_type:  "plan_change",
           amount_cents: 5_000,
           charge_data:  { "plan_change" => { "new_plan_id" => new_plan.id } })
  end

  let(:adapter) { instance_double(Gateways::AsaasAdapter) }

  before do
    allow(Gateways::Base).to receive(:for).with("asaas").and_return(adapter)
    allow(adapter).to receive(:update_subscription)
    allow(WebhookDispatchJob).to receive(:perform_later)

    # Período começa com a alocação do plano antigo + 1 pack extra
    period.subscription_period_credits.create!(
      credit_type: credit_type, base: 2_000, extras: 1_000, extra_packages: 1, quantity: 3_000
    )
    period.credit_snapshots.create!(
      credit_type: credit_type, used: 500, limit: 3_000, synced_at: Time.current
    )
  end

  after { ActsAsTenant.current_tenant = nil }

  it "aplica o novo plano na assinatura" do
    result = described_class.call(charge: charge)

    expect(result.success?).to be true
    expect(subscription.reload.plan_id).to eq(new_plan.id)
    expect(subscription.base_price_cents).to eq(20_000)
  end

  it "ajusta a base dos créditos do período preservando os extras" do
    described_class.call(charge: charge)

    spc = period.subscription_period_credits.find_by(credit_type: credit_type)
    expect(spc.base).to eq(5_000)       # nova base do plano
    expect(spc.extras).to eq(1_000)     # extra preservado
    expect(spc.quantity).to eq(6_000)   # base + extras

    snapshot = period.credit_snapshots.find_by(credit_type: credit_type)
    expect(snapshot.limit).to eq(6_000)
    expect(snapshot.balance).to eq(5_500) # 6000 - 500 usados
  end

  it "registra a troca de plano (subscription_plan_changes)" do
    expect {
      described_class.call(charge: charge)
    }.to change(subscription.subscription_plan_changes, :count).by(1)
  end

  it "retorna erro se o plano não existe" do
    charge.update!(charge_data: { "plan_change" => { "new_plan_id" => 999_999 } })
    result = described_class.call(charge: charge)
    expect(result.success?).to be false
  end
end

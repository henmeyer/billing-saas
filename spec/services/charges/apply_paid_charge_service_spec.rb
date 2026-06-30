require "rails_helper"

RSpec.describe Charges::ApplyPaidChargeService do
  let(:account)      { create(:account) }
  let(:customer)     { create(:customer, account: account) }
  let(:integration)  { create(:integration, account: account) }
  let(:subscription) { create(:subscription, customer: customer, integration: integration) }

  before do
    ActsAsTenant.current_tenant = account
    stub_const("Products::ApplyPurchaseService", Class.new do
      def self.call(charge:); end
    end)
    stub_const("Subscriptions::ApplyPlanChangeService", Class.new do
      def self.call(charge:); end
    end)
  end

  after { ActsAsTenant.current_tenant = nil }

  def build_charge(type, status: "paid")
    create(:charge,
           customer:     customer,
           subscription: subscription,
           status:       status,
           charge_type:  type)
  end

  it "roteia charge de produto para Products::ApplyPurchaseService" do
    charge = build_charge("product")
    expect(Products::ApplyPurchaseService).to receive(:call).with(charge: charge)

    expect(described_class.call(charge: charge)).to eq(:applied)
  end

  it "roteia charge de plan_change para Subscriptions::ApplyPlanChangeService" do
    charge = build_charge("plan_change")
    expect(Subscriptions::ApplyPlanChangeService).to receive(:call).with(charge: charge)

    expect(described_class.call(charge: charge)).to eq(:applied)
  end

  it "não faz nada para charge não paga" do
    charge = build_charge("product", status: "pending")
    expect(Products::ApplyPurchaseService).not_to receive(:call)

    expect(described_class.call(charge: charge)).to eq(:not_paid)
  end

  it "é idempotente: não aplica duas vezes" do
    charge = build_charge("product")

    expect(Products::ApplyPurchaseService).to receive(:call).once
    described_class.call(charge: charge)

    # segunda chamada não roteia de novo
    expect(described_class.call(charge: charge)).to eq(:already_applied)
  end

  it "marca applied_at em charge_data ao aplicar" do
    charge = build_charge("product")
    described_class.call(charge: charge)
    expect(charge.reload.charge_data["applied_at"]).to be_present
  end

  it "retorna :noop para tipos sem aplicação (ex: renewal)" do
    charge = build_charge("renewal")
    expect(described_class.call(charge: charge)).to eq(:noop)
  end
end

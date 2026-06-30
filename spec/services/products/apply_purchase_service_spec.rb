require "rails_helper"

RSpec.describe Products::ApplyPurchaseService do
  let(:account)      { create(:account) }
  let(:customer)     { create(:customer, account: account) }
  let(:integration)  { create(:integration, account: account) }
  let(:plan)         { create(:plan, account: account) }
  let(:credit_type)  { create(:credit_type, account: account, key: "coins") }
  let(:subscription) do
    create(:subscription, customer: customer, plan: plan, integration: integration, status: "active")
  end

  before { ActsAsTenant.current_tenant = account }

  let!(:period) do
    create(:subscription_period, subscription: subscription,
           period_start: 1.day.ago, period_end: 29.days.from_now,
           amount_cents: 10_000, base_amount_cents: 10_000, extras_amount_cents: 0)
  end

  before do
    allow(WebhookDispatchJob).to receive(:perform_later)
  end

  after { ActsAsTenant.current_tenant = nil }

  def charge_with(payload, amount_cents: 5_000)
    create(:charge,
           customer:     customer,
           subscription: subscription,
           amount_cents: amount_cents,
           status:       "paid",
           charge_type:  "product",
           charge_data:  { "product_purchase" => payload })
  end

  def pack_payload(product_type:, total:, qty:, credit: true)
    {
      "product_id"     => 99,
      "product_type"   => product_type,
      "credit_type_id" => credit ? credit_type.id : nil,
      "credit_per_unit" => 1000,
      "quantity"       => qty,
      "total_credits"  => total
    }
  end

  describe "credit_pack" do
    it "incrementa snapshot, spc (extras), valor de extras do período e metadata" do
      charge = charge_with(pack_payload(product_type: "credit_pack", total: 3000, qty: 3), amount_cents: 15_000)

      result = described_class.call(charge: charge)
      expect(result.success?).to be true

      snapshot = period.reload.credit_snapshots.find_by(credit_type: credit_type)
      expect(snapshot.limit).to eq(3000)
      expect(snapshot.balance).to eq(3000)

      spc = period.subscription_period_credits.find_by(credit_type: credit_type)
      expect(spc.extras).to eq(3000)
      expect(spc.extra_packages).to eq(3)
      expect(spc.quantity).to eq(3000)

      expect(period.reload.extras_amount_cents).to eq(15_000)
      expect(subscription.reload.metadata["product_packs"]).to eq({ "99" => 3 })
    end

    it "soma sobre snapshot/spc já existentes" do
      period.credit_snapshots.create!(credit_type: credit_type, used: 200, limit: 1000, synced_at: Time.current)
      period.subscription_period_credits.create!(credit_type: credit_type, base: 1000, extras: 0, extra_packages: 0, quantity: 1000)

      charge = charge_with(pack_payload(product_type: "credit_pack", total: 2000, qty: 2))
      described_class.call(charge: charge)

      snapshot = period.credit_snapshots.find_by(credit_type: credit_type)
      expect(snapshot.limit).to eq(3000)
      expect(snapshot.balance).to eq(2800) # 3000 - 200 used

      spc = period.subscription_period_credits.find_by(credit_type: credit_type)
      expect(spc.base).to eq(1000)
      expect(spc.extras).to eq(2000)
      expect(spc.quantity).to eq(3000)
    end

    it "dispara webhook credits.recharged" do
      charge = charge_with(pack_payload(product_type: "credit_pack", total: 1000, qty: 1))
      described_class.call(charge: charge)

      expect(WebhookDispatchJob).to have_received(:perform_later)
        .with(customer, "credits.recharged", hash_including(credit_type: "coins", added: 1000))
    end
  end

  describe "one_time com crédito" do
    it "incrementa apenas o snapshot do período (sem spc, sem metadata)" do
      charge = charge_with(pack_payload(product_type: "one_time", total: 500, qty: 1))
      described_class.call(charge: charge)

      snapshot = period.reload.credit_snapshots.find_by(credit_type: credit_type)
      expect(snapshot.limit).to eq(500)

      expect(period.subscription_period_credits.find_by(credit_type: credit_type)).to be_nil
      expect(period.reload.extras_amount_cents).to eq(0)
      expect(subscription.reload.metadata["product_packs"]).to be_nil
    end
  end

  describe "one_time sem crédito" do
    it "não altera créditos" do
      charge = charge_with(pack_payload(product_type: "one_time", total: 0, qty: 1, credit: false))
      result = described_class.call(charge: charge)

      expect(result.success?).to be true
      expect(period.reload.credit_snapshots).to be_empty
      expect(WebhookDispatchJob).not_to have_received(:perform_later)
    end
  end
end

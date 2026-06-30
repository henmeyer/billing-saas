require "rails_helper"
require "inertia_rails/rspec"

RSpec.describe "Portal::Dashboard", type: :request do
  let(:account)     { create(:account) }
  let(:currency)    { create(:currency, account: account, code: "BRL", default: true) }
  let(:integration) { create(:integration, account: account) }
  let(:customer)    { create(:customer, account: account, currency: currency) }
  let(:credit_type) { create(:credit_type, account: account, key: "coins", label: "Coins") }
  let(:plan)        { create(:plan, account: account, name: "Pro") }
  let(:raw_token)   { "portal-dash-token" }

  let(:subscription) do
    create(:subscription, :asaas,
           customer:             customer,
           plan:                 plan,
           integration:          integration,
           status:               "active",
           base_price_cents:     10_000,
           current_period_start: 5.days.ago,
           current_period_end:   25.days.from_now)
  end

  before { ActsAsTenant.current_tenant = account }

  let!(:period) do
    create(:subscription_period, subscription: subscription,
           period_start: 5.days.ago, period_end: 25.days.from_now,
           amount_cents: 15_000, base_amount_cents: 10_000, extras_amount_cents: 5_000)
  end

  before do
    create(:portal_session, customer: customer, integration: integration,
           token_digest: Digest::SHA256.hexdigest(raw_token))
    subscription
    # Crédito com pacote comprado (extras)
    period.subscription_period_credits.create!(
      credit_type: credit_type, base: 2_000, extras: 3_000, extra_packages: 3, quantity: 5_000
    )
    period.credit_snapshots.create!(
      credit_type: credit_type, used: 1_000, limit: 5_000, synced_at: Time.current
    )
  end

  after { ActsAsTenant.current_tenant = nil }

  it "expõe o breakdown base/extras dos créditos (pacotes comprados)" do
    ActsAsTenant.with_tenant(nil) do
      get "/portal/#{raw_token}"
    end

    credit = inertia.props[:credits].first
    expect(credit[:base]).to eq(2_000)
    expect(credit[:extras]).to eq(3_000)
    expect(credit[:extra_packages]).to eq(3)
    expect(credit[:limit]).to eq(5_000)
  end

  it "expõe scheduled_plan_change quando há downgrade agendado" do
    cheaper = create(:plan, account: account, name: "Basic")
    subscription.update!(metadata: {
      "scheduled_plan_change" => { "plan_id" => cheaper.id, "effective_at" => 25.days.from_now.iso8601 }
    })

    ActsAsTenant.with_tenant(nil) do
      get "/portal/#{raw_token}"
    end

    expect(inertia.props[:scheduled_plan_change][:plan_name]).to eq("Basic")
    expect(inertia.props[:scheduled_plan_change][:effective_at]).to be_present
  end

  it "scheduled_plan_change é nil sem agendamento" do
    ActsAsTenant.with_tenant(nil) do
      get "/portal/#{raw_token}"
    end

    expect(inertia.props[:scheduled_plan_change]).to be_nil
  end
end

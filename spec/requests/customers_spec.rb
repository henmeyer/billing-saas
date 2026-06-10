require "rails_helper"
require "inertia_rails/rspec"

RSpec.describe "Customers", type: :request do
  let(:account)  { create(:account) }
  let(:user)     { create(:user) }
  let(:customer) { create(:customer, account: account) }

  before do
    create(:account_user, account: account, user: user, role: "admin")
    sign_in user
    set_tenant(account)
  end

  after { ActsAsTenant.current_tenant = nil }

  describe "GET /customers/:id" do
    context "with multiple active subscriptions" do
      let(:integration_a) { create(:integration, account: account, name: "Integration A") }
      let(:integration_b) { create(:integration, account: account, name: "Integration B") }
      let(:plan_a) { create(:plan, account: account, name: "Plan A", price_cents: 10000) }
      let(:plan_b) { create(:plan, account: account, name: "Plan B", price_cents: 20000) }

      let!(:sub_a) do
        create(:subscription,
               customer: customer,
               plan: plan_a,
               integration: integration_a,
               status: "active",
               base_price_cents: 10000)
      end

      let!(:sub_b) do
        create(:subscription,
               customer: customer,
               plan: plan_b,
               integration: integration_b,
               status: "trialing",
               base_price_cents: 20000)
      end

      it "serializes all active subscriptions as an array" do
        get customer_path(customer)

        expect(inertia).to render_component("Customers/Show")

        subscriptions = inertia.props[:subscriptions]
        expect(subscriptions).to be_an(Array)
        expect(subscriptions.length).to eq(2)
      end

      it "includes integration_name in each subscription" do
        get customer_path(customer)

        subscriptions = inertia.props[:subscriptions]
        integration_names = subscriptions.map { |s| s[:integration_name] }
        expect(integration_names).to contain_exactly("Integration A", "Integration B")
      end

      it "includes value breakdown in each subscription" do
        create(:subscription_period,
               subscription: sub_a,
               period_start: 1.day.ago,
               period_end: 29.days.from_now,
               amount_cents: 15000,
               base_amount_cents: 10000,
               extras_amount_cents: 5000)

        get customer_path(customer)

        subscriptions = inertia.props[:subscriptions]
        sub_with_extras = subscriptions.find { |s| s[:integration_name] == "Integration A" }

        expect(sub_with_extras[:period_amount_cents]).to eq(15000)
        expect(sub_with_extras[:period_base_cents]).to eq(10000)
        expect(sub_with_extras[:period_extras_cents]).to eq(5000)
        expect(sub_with_extras[:has_extras]).to be true
      end

      it "includes plan_name in each subscription" do
        get customer_path(customer)

        subscriptions = inertia.props[:subscriptions]
        plan_names = subscriptions.map { |s| s[:plan_name] }
        expect(plan_names).to contain_exactly("Plan A", "Plan B")
      end

      it "includes status in each subscription" do
        get customer_path(customer)

        subscriptions = inertia.props[:subscriptions]
        statuses = subscriptions.map { |s| s[:status] }
        expect(statuses).to contain_exactly("active", "trialing")
      end

      it "keeps backward-compatible subscription prop as first active subscription" do
        get customer_path(customer)

        subscription = inertia.props[:subscription]
        expect(subscription).not_to be_nil
        expect(subscription[:id]).to eq(inertia.props[:subscriptions].first[:id])
      end
    end

    context "with no active subscriptions" do
      let!(:cancelled_sub) do
        create(:subscription, :cancelled,
               customer: customer,
               integration: create(:integration, account: account))
      end

      it "returns empty subscriptions array and nil subscription" do
        get customer_path(customer)

        expect(inertia.props[:subscriptions]).to eq([])
        expect(inertia.props[:subscription]).to be_nil
      end
    end

    context "with subscription including extras" do
      let(:integration) { create(:integration, account: account, name: "Main Integration") }
      let(:plan) { create(:plan, account: account, name: "Pro Plan", price_cents: 19700) }

      let!(:subscription) do
        create(:subscription,
               customer: customer,
               plan: plan,
               integration: integration,
               status: "active",
               base_price_cents: 19700)
      end

      it "shows has_extras as false when no extras exist" do
        create(:subscription_period,
               subscription: subscription,
               period_start: 1.day.ago,
               period_end: 29.days.from_now,
               amount_cents: 19700,
               base_amount_cents: 19700,
               extras_amount_cents: 0)

        get customer_path(customer)

        sub_data = inertia.props[:subscriptions].first
        expect(sub_data[:has_extras]).to be false
        expect(sub_data[:period_extras_cents]).to eq(0)
        expect(sub_data[:period_amount_cents]).to eq(19700)
      end

      it "shows has_extras as true when extras exist" do
        create(:subscription_period,
               subscription: subscription,
               period_start: 1.day.ago,
               period_end: 29.days.from_now,
               amount_cents: 25000,
               base_amount_cents: 19700,
               extras_amount_cents: 5300)

        get customer_path(customer)

        sub_data = inertia.props[:subscriptions].first
        expect(sub_data[:has_extras]).to be true
        expect(sub_data[:period_extras_cents]).to eq(5300)
        expect(sub_data[:period_amount_cents]).to eq(25000)
        expect(sub_data[:period_base_cents]).to eq(19700)
      end
    end

    context "excludes cancelled subscriptions from array" do
      let(:integration_a) { create(:integration, account: account, name: "Active Int") }
      let(:integration_b) { create(:integration, account: account, name: "Cancelled Int") }

      let!(:active_sub) do
        create(:subscription,
               customer: customer,
               integration: integration_a,
               status: "active",
               base_price_cents: 10000)
      end

      let!(:cancelled_sub) do
        create(:subscription, :cancelled,
               customer: customer,
               integration: integration_b)
      end

      it "only includes active/trialing/past_due subscriptions" do
        get customer_path(customer)

        subscriptions = inertia.props[:subscriptions]
        expect(subscriptions.length).to eq(1)
        expect(subscriptions.first[:integration_name]).to eq("Active Int")
      end
    end
  end
end

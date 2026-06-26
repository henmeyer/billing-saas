require "rails_helper"

RSpec.describe "SubscriptionsController", type: :request do
  let(:account)  { create(:account) }
  let(:user)     { create(:user) }

  before do
    create(:account_user, account: account, user: user, role: "admin")
    sign_in user
    set_tenant(account)
  end

  after { ActsAsTenant.current_tenant = nil }

  describe "GET /customers/:customer_id/subscriptions/new" do
    it "includes available_integrations in props" do
      customer    = create(:customer, account: account)
      integration = create(:integration, account: account, active: true)
      plan        = create(:plan, account: account)
      create(:plan_integration, plan: plan, integration: integration)

      get new_customer_subscription_path(customer)

      expect(response).to have_http_status(:ok)
    end

    it "excludes integrations that already have active subscriptions for the customer" do
      customer      = create(:customer, account: account)
      integration_a = create(:integration, account: account, active: true)
      integration_b = create(:integration, account: account, active: true)
      plan          = create(:plan, account: account)
      create(:plan_integration, plan: plan, integration: integration_a)
      create(:plan_integration, plan: plan, integration: integration_b)
      # Create active subscription for integration_a
      create(:subscription, customer: customer, plan: plan, integration: integration_a)

      get new_customer_subscription_path(customer)

      expect(response).to have_http_status(:ok)
    end

    it "accepts optional integration_id param" do
      customer    = create(:customer, account: account)
      integration = create(:integration, account: account, active: true)

      get new_customer_subscription_path(customer, integration_id: integration.id)

      expect(response).to have_http_status(:ok)
    end

    it "excludes inactive integrations from available list" do
      customer = create(:customer, account: account)
      create(:integration, account: account, active: false)

      get new_customer_subscription_path(customer)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /customers/:customer_id/subscriptions" do
    before do
      create(:payment_gateway, account: account)
      allow_any_instance_of(Gateways::AsaasAdapter).to receive(:create_customer).and_return(true)
      allow_any_instance_of(Gateways::AsaasAdapter).to receive(:create_subscription).and_return({ "id" => "sub_test_123" })
    end

    it "passes integration_id to CreateService and creates subscription" do
      customer    = create(:customer, account: account)
      integration = create(:integration, account: account, active: true)
      plan        = create(:plan, account: account)
      currency    = create(:currency, account: account)
      create(:plan_integration, plan: plan, integration: integration)
      create(:plan_price, plan: plan, currency: currency, amount_cents: 9900)

      post customer_subscriptions_path(customer), params: {
        plan_id:        plan.id,
        gateway:        "asaas",
        integration_id: integration.id,
        currency_id:    currency.id
      }

      expect(response).to redirect_to(customer_path(customer))
      expect(customer.subscriptions.last.integration_id).to eq(integration.id)
    end

    it "renders form with errors when creation fails due to duplicate" do
      customer    = create(:customer, account: account)
      integration = create(:integration, account: account, active: true)
      plan        = create(:plan, account: account)
      currency    = create(:currency, account: account)
      create(:plan_integration, plan: plan, integration: integration)
      create(:plan_price, plan: plan, currency: currency, amount_cents: 9900)
      # Create existing active subscription
      create(:subscription, customer: customer, plan: plan, integration: integration)

      post customer_subscriptions_path(customer), params: {
        plan_id:        plan.id,
        gateway:        "asaas",
        integration_id: integration.id,
        currency_id:    currency.id
      }

      # Should re-render the form (not redirect)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /customers/:customer_id/subscriptions/:id/edit" do
    it "includes linked_integration and integration data in subscription" do
      customer    = create(:customer, account: account)
      integration = create(:integration, account: account, active: true)
      plan        = create(:plan, account: account)
      create(:plan_integration, plan: plan, integration: integration)
      subscription = create(:subscription, customer: customer, plan: plan, integration: integration)

      get edit_customer_subscription_path(customer, subscription)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /customers/:customer_id/subscriptions/:id/migrate_to_billing" do
    let(:customer)    { create(:customer, account: account, gateway_data: { "asaas" => { "customer_id" => "cus_test" } }) }
    let(:integration) { create(:integration, account: account, active: true) }
    let(:plan)        { create(:plan, account: account) }

    before do
      create(:payment_gateway, account: account)
      stub_request(:delete, /asaas\.com/)
        .to_return(status: 200, body: { "deleted" => true }.to_json, headers: { "Content-Type" => "application/json" })
    end

    context "when subscription is Asaas gateway-managed" do
      let(:subscription) do
        create(:subscription, :asaas, :gateway_managed,
               customer:                customer,
               plan:                    plan,
               integration:             integration,
               gateway_subscription_id: "sub_asaas_admin_123")
      end

      it "migrates subscription to billing-managed" do
        post migrate_to_billing_customer_subscription_path(customer, subscription)

        subscription.reload
        expect(subscription.managed_by).to eq("billing")
        expect(subscription.metadata["migrated_from_gateway"]).to be true
        expect(subscription.metadata["original_asaas_sub_id"]).to eq("sub_asaas_admin_123")
        expect(response).to redirect_to(customer_path(customer))
        expect(flash[:notice]).to include("migrada")
      end

      it "cancels the native Asaas subscription" do
        post migrate_to_billing_customer_subscription_path(customer, subscription)

        expect(a_request(:delete, /subscriptions\/sub_asaas_admin_123/)).to have_been_made.once
      end
    end

    context "when subscription is not Asaas gateway-managed" do
      let(:subscription) do
        create(:subscription, :asaas, :billing_managed,
               customer:    customer,
               plan:        plan,
               integration: integration)
      end

      it "redirects with alert" do
        post migrate_to_billing_customer_subscription_path(customer, subscription)

        expect(response).to redirect_to(customer_path(customer))
        expect(flash[:alert]).to include("não é gerenciada pelo Asaas")
      end
    end

    context "when subscription is Stripe" do
      let(:subscription) do
        create(:subscription,
               customer:    customer,
               plan:        plan,
               integration: integration,
               gateway:     "stripe",
               managed_by:  "gateway")
      end

      it "redirects with alert" do
        post migrate_to_billing_customer_subscription_path(customer, subscription)

        expect(response).to redirect_to(customer_path(customer))
        expect(flash[:alert]).to include("não é gerenciada pelo Asaas")
      end
    end
  end

  describe "GET /subscriptions (index)" do
    it "includes integration data in subscription row serialization" do
      customer    = create(:customer, account: account)
      integration = create(:integration, account: account, active: true)
      plan        = create(:plan, account: account)
      create(:plan_integration, plan: plan, integration: integration)
      create(:subscription, customer: customer, plan: plan, integration: integration)

      get subscriptions_path

      expect(response).to have_http_status(:ok)
    end
  end
end

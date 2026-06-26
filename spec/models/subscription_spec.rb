require "rails_helper"

RSpec.describe Subscription, type: :model do
  let(:account) { create(:account) }

  before { set_tenant(account) }

  describe "associations" do
    it { should belong_to(:customer) }
    it { should belong_to(:plan) }
    it { should belong_to(:integration) }
    it { should belong_to(:currency).optional }
    it { should have_many(:subscription_periods).dependent(:destroy) }
    it { should have_many(:charges) }
    it { should have_many(:subscription_plan_changes) }
  end

  describe "validations" do
    it { should validate_presence_of(:integration_id) }
    it { should validate_inclusion_of(:status).in_array(Subscription::STATUSES) }
    it { should validate_inclusion_of(:gateway).in_array(Subscription::GATEWAYS) }
    it { should validate_inclusion_of(:managed_by).in_array(Subscription::MANAGED_BY) }
  end

  describe "managed_by scopes and helpers" do
    let(:customer) { create(:customer, account: account) }
    let(:plan) { create(:plan, account: account) }

    it "scope :gateway_managed returns only gateway-managed subscriptions" do
      integration1 = create(:integration, account: account)
      integration2 = create(:integration, account: account)

      gw_sub = create(:subscription, customer: customer, plan: plan, integration: integration1,
                                     status: "active", managed_by: "gateway")
      bl_sub = create(:subscription, customer: customer, plan: plan, integration: integration2,
                                     status: "active", managed_by: "billing")

      expect(Subscription.gateway_managed).to include(gw_sub)
      expect(Subscription.gateway_managed).not_to include(bl_sub)
    end

    it "scope :billing_managed returns only billing-managed subscriptions" do
      integration1 = create(:integration, account: account)
      integration2 = create(:integration, account: account)

      gw_sub = create(:subscription, customer: customer, plan: plan, integration: integration1,
                                     status: "active", managed_by: "gateway")
      bl_sub = create(:subscription, customer: customer, plan: plan, integration: integration2,
                                     status: "active", managed_by: "billing")

      expect(Subscription.billing_managed).to include(bl_sub)
      expect(Subscription.billing_managed).not_to include(gw_sub)
    end

    it "#gateway_managed? returns true for gateway-managed subscriptions" do
      sub = build(:subscription, managed_by: "gateway")
      expect(sub.gateway_managed?).to be true
      expect(sub.billing_managed?).to be false
    end

    it "#billing_managed? returns true for billing-managed subscriptions" do
      sub = build(:subscription, managed_by: "billing")
      expect(sub.billing_managed?).to be true
      expect(sub.gateway_managed?).to be false
    end

    it "defaults to gateway when not specified" do
      sub = Subscription.new
      expect(sub.managed_by).to eq("gateway")
      expect(sub.gateway_managed?).to be true
    end

    it "rejects invalid managed_by values" do
      sub = build(:subscription, managed_by: "invalid")
      expect(sub).not_to be_valid
      expect(sub.errors[:managed_by]).to be_present
    end
  end

  describe "unique_active_per_integration" do
    let(:customer) { create(:customer, account: account) }
    let(:integration) { create(:integration, account: account) }
    let(:plan) { create(:plan, account: account) }

    context "when an active subscription already exists for the same customer+integration" do
      before do
        create(:subscription,
               customer:    customer,
               integration: integration,
               plan:        plan,
               status:      "active")
      end

      it "rejects creating another active subscription" do
        duplicate = build(:subscription,
                          customer:    customer,
                          integration: integration,
                          plan:        plan,
                          status:      "active")
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:integration_id]).to include("já possui assinatura ativa nesta integração")
      end

      it "rejects creating a trialing subscription" do
        duplicate = build(:subscription,
                          customer:    customer,
                          integration: integration,
                          plan:        plan,
                          status:      "trialing")
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:integration_id]).to include("já possui assinatura ativa nesta integração")
      end

      it "rejects creating a past_due subscription" do
        duplicate = build(:subscription,
                          customer:    customer,
                          integration: integration,
                          plan:        plan,
                          status:      "past_due")
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:integration_id]).to include("já possui assinatura ativa nesta integração")
      end
    end

    context "when a cancelled subscription exists for the same customer+integration" do
      before do
        create(:subscription, :cancelled,
               customer:    customer,
               integration: integration,
               plan:        plan)
      end

      it "allows creating a new active subscription" do
        new_sub = build(:subscription,
                        customer:    customer,
                        integration: integration,
                        plan:        plan,
                        status:      "active")
        expect(new_sub).to be_valid
      end
    end

    context "when active subscription exists for a different integration" do
      let(:other_integration) { create(:integration, account: account) }

      before do
        create(:subscription,
               customer:    customer,
               integration: other_integration,
               plan:        plan,
               status:      "active")
      end

      it "allows creating an active subscription for a different integration" do
        new_sub = build(:subscription,
                        customer:    customer,
                        integration: integration,
                        plan:        plan,
                        status:      "active")
        expect(new_sub).to be_valid
      end
    end
  end

  describe "scope :active" do
    let(:customer) { create(:customer, account: account) }
    let(:plan) { create(:plan, account: account) }

    it "includes active, trialing, and past_due subscriptions" do
      integration1 = create(:integration, account: account)
      integration2 = create(:integration, account: account)
      integration3 = create(:integration, account: account)
      integration4 = create(:integration, account: account)

      active_sub = create(:subscription, customer: customer, plan: plan, integration: integration1, status: "active")
      trialing_sub = create(:subscription, customer: customer, plan: plan, integration: integration2, status: "trialing")
      past_due_sub = create(:subscription, customer: customer, plan: plan, integration: integration3, status: "past_due")
      cancelled_sub = create(:subscription, :cancelled, customer: customer, plan: plan, integration: integration4)

      active_subs = Subscription.active

      expect(active_subs).to include(active_sub, trialing_sub, past_due_sub)
      expect(active_subs).not_to include(cancelled_sub)
    end
  end

  describe "attr_readonly :integration_id" do
    let(:customer) { create(:customer, account: account) }
    let(:plan) { create(:plan, account: account) }
    let(:integration) { create(:integration, account: account) }
    let(:other_integration) { create(:integration, account: account) }

    it "raises error when trying to change integration_id after creation" do
      subscription = create(:subscription,
                            customer:    customer,
                            plan:        plan,
                            integration: integration,
                            status:      "active")

      expect {
        subscription.update!(integration_id: other_integration.id)
      }.to raise_error(ActiveRecord::ReadonlyAttributeError)

      subscription.reload
      expect(subscription.integration_id).to eq(integration.id)
    end
  end

  describe "webhook de ativação (independente do gateway)" do
    let(:customer)     { create(:customer, account: account) }
    let(:plan)         { create(:plan, account: account) }
    let(:integration)  { create(:integration, account: account) }

    before { allow(WebhookDispatchJob).to receive(:perform_later) }

    %w[stripe asaas dlocal_go].each do |gateway_name|
      it "dispara subscription.activated quando o status muda para active via #{gateway_name}" do
        sub = create(:subscription,
                     customer:    customer,
                     plan:        plan,
                     integration: integration,
                     gateway:     gateway_name,
                     status:      "pending")

        sub.update!(status: "active")

        expect(WebhookDispatchJob).to have_received(:perform_later).with(
          customer,
          "subscription.activated",
          hash_including(plan: { id: plan.id, name: plan.name }, gateway: gateway_name)
        )
      end
    end

    it "marca converted_from_trial quando vem de trialing" do
      sub = create(:subscription,
                   customer:    customer,
                   plan:        plan,
                   integration: integration,
                   gateway:     nil,
                   status:      "trialing")

      sub.update!(status: "active", gateway: "asaas")

      expect(WebhookDispatchJob).to have_received(:perform_later).with(
        customer,
        "subscription.activated",
        hash_including(converted_from_trial: true)
      )
    end

    it "não dispara quando o status muda para algo diferente de active" do
      sub = create(:subscription, customer: customer, plan: plan, integration: integration, status: "active")

      sub.update!(status: "past_due")

      expect(WebhookDispatchJob).not_to have_received(:perform_later)
        .with(anything, "subscription.activated", anything)
    end

    it "não dispara quando status permanece active" do
      sub = create(:subscription, customer: customer, plan: plan, integration: integration, status: "active")

      sub.update!(base_price_cents: 1000)

      expect(WebhookDispatchJob).not_to have_received(:perform_later)
        .with(anything, "subscription.activated", anything)
    end
  end
end

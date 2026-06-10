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
  end

  describe "unique_active_per_integration" do
    let(:customer) { create(:customer, account: account) }
    let(:integration) { create(:integration, account: account) }
    let(:plan) { create(:plan, account: account) }

    context "when an active subscription already exists for the same customer+integration" do
      before do
        create(:subscription,
               customer: customer,
               integration: integration,
               plan: plan,
               status: "active")
      end

      it "rejects creating another active subscription" do
        duplicate = build(:subscription,
                          customer: customer,
                          integration: integration,
                          plan: plan,
                          status: "active")
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:integration_id]).to include("já possui assinatura ativa nesta integração")
      end

      it "rejects creating a trialing subscription" do
        duplicate = build(:subscription,
                          customer: customer,
                          integration: integration,
                          plan: plan,
                          status: "trialing")
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:integration_id]).to include("já possui assinatura ativa nesta integração")
      end

      it "rejects creating a past_due subscription" do
        duplicate = build(:subscription,
                          customer: customer,
                          integration: integration,
                          plan: plan,
                          status: "past_due")
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:integration_id]).to include("já possui assinatura ativa nesta integração")
      end
    end

    context "when a cancelled subscription exists for the same customer+integration" do
      before do
        create(:subscription, :cancelled,
               customer: customer,
               integration: integration,
               plan: plan)
      end

      it "allows creating a new active subscription" do
        new_sub = build(:subscription,
                        customer: customer,
                        integration: integration,
                        plan: plan,
                        status: "active")
        expect(new_sub).to be_valid
      end
    end

    context "when active subscription exists for a different integration" do
      let(:other_integration) { create(:integration, account: account) }

      before do
        create(:subscription,
               customer: customer,
               integration: other_integration,
               plan: plan,
               status: "active")
      end

      it "allows creating an active subscription for a different integration" do
        new_sub = build(:subscription,
                        customer: customer,
                        integration: integration,
                        plan: plan,
                        status: "active")
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
                            customer: customer,
                            plan: plan,
                            integration: integration,
                            status: "active")

      expect {
        subscription.update!(integration_id: other_integration.id)
      }.to raise_error(ActiveRecord::ReadonlyAttributeError)

      subscription.reload
      expect(subscription.integration_id).to eq(integration.id)
    end
  end
end

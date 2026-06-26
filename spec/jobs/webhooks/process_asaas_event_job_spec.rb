require "rails_helper"

RSpec.describe Webhooks::ProcessAsaasEventJob do
  let(:account)     { create(:account) }
  let(:customer)    { create(:customer, account: account) }
  let(:plan)        { create(:plan, account: account) }
  let(:integration) { create(:integration, account: account) }

  before do
    set_tenant(account)
    allow(WebhookDispatchJob).to receive(:perform_later)
  end

  after { ActsAsTenant.current_tenant = nil }

  # ─── Gateway-managed (legado) ───────────────────────────────────────

  describe "gateway-managed subscriptions" do
    let(:sub) do
      create(:subscription, :asaas, :gateway_managed,
             customer:                customer,
             plan:                    plan,
             integration:             integration,
             gateway_subscription_id: "sub_asaas_native_123",
             base_price_cents:        9900)
    end

    describe "payment_received" do
      let(:payload) do
        {
          "payment" => {
            "id"                => "pay_gw_001",
            "subscription"      => sub.gateway_subscription_id,
            "value"             => 99.0,
            "dueDate"           => Date.today.to_s,
            "paymentDate"       => Date.today.to_s,
            "externalReference" => ""
          }
        }
      end

      it "cria charge paid" do
        expect {
          described_class.perform_now("payment_received", payload)
        }.to change(Charge, :count).by(1)

        charge = Charge.last
        expect(charge.status).to eq("paid")
        expect(charge.amount_cents).to eq(9900)
        expect(charge.gateway_charge_id).to eq("pay_gw_001")
      end

      it "ativa subscription e renova período" do
        described_class.perform_now("payment_received", payload)

        sub.reload
        expect(sub.status).to eq("active")
        expect(sub.current_period_start).to be_present
        expect(sub.current_period_end).to be_present
      end

      it "cria subscription_period" do
        expect {
          described_class.perform_now("payment_received", payload)
        }.to change(SubscriptionPeriod, :count).by(1)
      end

      it "é idempotente — não duplica charge" do
        described_class.perform_now("payment_received", payload)
        expect {
          described_class.perform_now("payment_received", payload)
        }.not_to change(Charge, :count)
      end

      it "dispara webhooks payment.received e subscription.renewed" do
        described_class.perform_now("payment_received", payload)

        expect(WebhookDispatchJob).to have_received(:perform_later).with(
          customer, "payment.received",
          hash_including(amount_cents: 9900, gateway: "asaas")
        )
        expect(WebhookDispatchJob).to have_received(:perform_later).with(
          customer, "subscription.renewed", anything
        )
      end
    end

    describe "payment_overdue" do
      it "marca subscription como past_due" do
        described_class.perform_now("payment_overdue", {
          "payment" => { "subscription" => sub.gateway_subscription_id }
        })
        expect(sub.reload.status).to eq("past_due")
      end

      it "dispara webhook subscription.past_due" do
        described_class.perform_now("payment_overdue", {
          "payment" => { "subscription" => sub.gateway_subscription_id }
        })
        expect(WebhookDispatchJob).to have_received(:perform_later).with(
          customer, "subscription.past_due", {}
        )
      end
    end

    describe "subscription_cancelled" do
      it "cancela subscription" do
        described_class.perform_now("subscription_cancelled", {
          "subscription" => { "id" => sub.gateway_subscription_id }
        })
        sub.reload
        expect(sub.status).to eq("cancelled")
        expect(sub.cancelled_at).to be_present
      end
    end
  end

  # ─── Billing-managed (novo) ─────────────────────────────────────────

  describe "billing-managed subscriptions" do
    let(:sub) do
      create(:subscription, :asaas, :billing_managed,
             customer:                customer,
             plan:                    plan,
             integration:             integration,
             gateway_subscription_id: "sub_#{customer.id}_1700000000",
             status:                  "active",
             base_price_cents:        9900,
             current_period_start:    1.month.ago,
             current_period_end:      1.hour.ago)
    end

    describe "payment_received via externalReference (charge_ format)" do
      let(:payload) do
        {
          "payment" => {
            "id"                => "pay_bm_001",
            "subscription"      => nil,
            "value"             => 99.0,
            "dueDate"           => Date.today.to_s,
            "paymentDate"       => Date.today.to_s,
            "externalReference" => "charge_#{customer.id}_1700000001"
          }
        }
      end

      before { sub } # ensure subscription exists

      it "encontra subscription via externalReference" do
        described_class.perform_now("payment_received", payload)
        expect(sub.reload.status).to eq("active")
      end

      it "cria charge e subscription_period" do
        expect {
          described_class.perform_now("payment_received", payload)
        }.to change(Charge, :count).by(1)
           .and change(SubscriptionPeriod, :count).by(1)
      end

      it "renova o período (billing-managed)" do
        described_class.perform_now("payment_received", payload)

        sub.reload
        expect(sub.current_period_start).to eq(Time.current.beginning_of_day)
        expect(sub.current_period_end).to be > Time.current
      end

      it "dispara payment.received e subscription.renewed" do
        described_class.perform_now("payment_received", payload)

        expect(WebhookDispatchJob).to have_received(:perform_later).with(
          customer, "payment.received",
          hash_including(amount_cents: 9900, charge_id: "pay_bm_001")
        )
        expect(WebhookDispatchJob).to have_received(:perform_later).with(
          customer, "subscription.renewed", anything
        )
      end
    end

    describe "payment_received com charge existente (RenewAsaasJob criou)" do
      let!(:pending_charge) do
        create(:charge, :pending,
               customer:          customer,
               subscription:      sub,
               gateway:           "asaas",
               gateway_charge_id: "pay_renew_002",
               amount_cents:      9900,
               charge_type:       "renewal")
      end

      let(:payload) do
        {
          "payment" => {
            "id"                => "pay_renew_002",
            "subscription"      => nil,
            "value"             => 99.0,
            "dueDate"           => Date.today.to_s,
            "paymentDate"       => Date.today.to_s,
            "externalReference" => "charge_#{customer.id}_1700000002"
          }
        }
      end

      it "atualiza charge existente para paid em vez de criar nova" do
        expect {
          described_class.perform_now("payment_received", payload)
        }.not_to change(Charge, :count)

        pending_charge.reload
        expect(pending_charge.status).to eq("paid")
        expect(pending_charge.paid_at).to be_present
      end
    end

    describe "primeiro pagamento (pending → active)" do
      let(:pending_sub) do
        create(:subscription, :asaas, :billing_managed,
               customer:                customer,
               plan:                    plan,
               integration:             integration,
               gateway_subscription_id: "sub_#{customer.id}_1700000003",
               status:                  "pending",
               base_price_cents:        9900)
      end

      let!(:initial_period) do
        create(:subscription_period,
               subscription: pending_sub,
               period_start: Time.current.beginning_of_day,
               period_end:   1.month.from_now.beginning_of_day)
      end

      let(:payload) do
        {
          "payment" => {
            "id"                => "pay_first_003",
            "subscription"      => nil,
            "value"             => 99.0,
            "dueDate"           => Date.today.to_s,
            "paymentDate"       => Date.today.to_s,
            "externalReference" => "charge_#{customer.id}_1700000003"
          }
        }
      end

      it "ativa subscription e marca converted_at" do
        described_class.perform_now("payment_received", payload)

        pending_sub.reload
        expect(pending_sub.status).to eq("active")
        expect(pending_sub.converted_at).to be_present
      end

      it "dispara subscription.activated via callback do model" do
        described_class.perform_now("payment_received", payload)

        expect(WebhookDispatchJob).to have_received(:perform_later).with(
          customer, "subscription.activated",
          hash_including(plan: { id: plan.id, name: plan.name })
        )
      end

      it "não dispara payment.received para primeiro pagamento" do
        described_class.perform_now("payment_received", payload)

        expect(WebhookDispatchJob).not_to have_received(:perform_later).with(
          customer, "payment.received", anything
        )
      end

      it "atualiza período existente em vez de criar novo" do
        expect {
          described_class.perform_now("payment_received", payload)
        }.not_to change(SubscriptionPeriod, :count)

        initial_period.reload
        expect(initial_period.amount_cents).to eq(9900)
      end
    end
  end

  # ─── Localização por gateway_charge_id (fallback) ───────────────────

  describe "finding subscription via existing charge" do
    let(:sub) do
      create(:subscription, :asaas, :billing_managed,
             customer:                customer,
             plan:                    plan,
             integration:             integration,
             gateway_subscription_id: "sub_#{customer.id}_1700000004",
             status:                  "active",
             base_price_cents:        5000)
    end

    let!(:existing_charge) do
      create(:charge, :pending,
             customer:          customer,
             subscription:      sub,
             gateway:           "asaas",
             gateway_charge_id: "pay_existing_004",
             amount_cents:      5000)
    end

    let(:payload) do
      {
        "payment" => {
          "id"                => "pay_existing_004",
          "subscription"      => nil,
          "value"             => 50.0,
          "dueDate"           => Date.today.to_s,
          "paymentDate"       => Date.today.to_s,
          "externalReference" => ""
        }
      }
    end

    it "encontra subscription via charge existente" do
      described_class.perform_now("payment_received", payload)

      existing_charge.reload
      expect(existing_charge.status).to eq("paid")
    end
  end

  # ─── Refund ─────────────────────────────────────────────────────────

  describe "payment_refunded" do
    let(:sub) do
      create(:subscription, :asaas,
             customer:                customer,
             plan:                    plan,
             integration:             integration,
             gateway_subscription_id: "sub_asaas_refund_123",
             base_price_cents:        9900)
    end

    let!(:charge) do
      create(:charge,
             customer:          customer,
             subscription:      sub,
             gateway:           "asaas",
             gateway_charge_id: "pay_refund_005",
             amount_cents:      9900,
             status:            "paid")
    end

    it "marca charge como refunded" do
      described_class.perform_now("payment_refunded", {
        "payment" => {
          "id"           => "pay_refund_005",
          "subscription" => sub.gateway_subscription_id
        }
      })

      charge.reload
      expect(charge.status).to eq("refunded")
    end
  end

  # ─── Subscription não encontrada ────────────────────────────────────

  describe "quando subscription não existe" do
    it "retorna sem erro" do
      expect {
        described_class.perform_now("payment_received", {
          "payment" => {
            "id"                => "pay_unknown",
            "subscription"      => "sub_inexistente",
            "value"             => 50.0,
            "externalReference" => ""
          }
        })
      }.not_to raise_error
    end
  end
end

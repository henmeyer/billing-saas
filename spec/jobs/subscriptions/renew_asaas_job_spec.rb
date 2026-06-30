# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::RenewAsaasJob, type: :job do
  let(:account) { create(:account) }
  let(:customer) { create(:customer, account: account, gateway_data: { "asaas" => { "customer_id" => "cus_test" } }) }
  let(:plan) { create(:plan, account: account) }
  let(:integration) { create(:integration, account: account) }
  let(:currency) { create(:currency, account: account, code: "BRL", default: true) }

  let(:subscription) do
    create(:subscription, :asaas, :billing_managed,
           customer:             customer,
           plan:                 plan,
           integration:          integration,
           status:               "active",
           current_period_end:   1.hour.ago,
           current_period_start: 1.month.ago,
           base_price_cents:     9900)
  end

  let(:payment_gateway) { create(:payment_gateway, account: account, provider: "asaas") }

  let(:adapter) { instance_double(Gateways::AsaasAdapter) }
  let(:pricing_result) do
    Pricing::CalculateService::Result.new(
      amount_cents: 9900,
      quantity:     1,
      tier:         nil,
      breakdown:    { type: "flat", amount_cents: 9900 },
      currency:     currency,
      extras_breakdown: []
    )
  end

  before do
    set_tenant(account)
    currency         # force creation
    payment_gateway  # force creation after tenant
    subscription     # force creation after tenant

    allow(Gateways::AsaasAdapter).to receive(:new).and_return(adapter)
    allow(Pricing::CalculateService).to receive(:call).and_return(pricing_result)
    allow(WebhookDispatchJob).to receive(:perform_later)
  end

  describe "#perform" do
    context "when subscription is billing-managed and due for renewal" do
      before do
        allow(adapter).to receive(:create_charge).and_return({
          "id"          => "pay_renewal_123",
          "status"      => "PENDING",
          "billingType" => "PIX",
          "invoiceUrl"  => "https://asaas.com/invoice/renewal"
        })
      end

      it "creates a charge via AsaasAdapter" do
        described_class.perform_now

        expect(adapter).to have_received(:create_charge).with(
          customer,
          9900,
          hash_including(
            description: "#{plan.name} — Renovação",
            due_date:    Date.current.strftime("%Y-%m-%d")
          )
        )
      end

      it "creates a pending charge record" do
        expect { described_class.perform_now }.to change(Charge, :count).by(1)

        charge = subscription.charges.last
        expect(charge.status).to eq("pending")
        expect(charge.gateway).to eq("asaas")
        expect(charge.gateway_charge_id).to eq("pay_renewal_123")
        expect(charge.amount_cents).to eq(9900)
        expect(charge.charge_type).to eq("renewal")
        expect(charge.charge_data["renewal"]).to be true
        expect(charge.charge_data["billing_type"]).to eq("PIX")
      end

      it "dispatches subscription.renewal_pending webhook" do
        described_class.perform_now

        expect(WebhookDispatchJob).to have_received(:perform_later).with(
          customer,
          "subscription.renewal_pending",
          hash_including(
            gateway:      "asaas",
            amount_cents: 9900,
            invoice_url:  "https://asaas.com/invoice/renewal"
          )
        )
      end
    end

    context "when subscription is gateway-managed" do
      before do
        subscription.update!(managed_by: "gateway")
        allow(adapter).to receive(:create_charge)
      end

      it "does not process gateway-managed subscriptions" do
        described_class.perform_now
        expect(adapter).not_to have_received(:create_charge)
      end
    end

    context "when subscription is not yet due" do
      before do
        subscription.update!(current_period_end: 5.days.from_now)
        allow(adapter).to receive(:create_charge)
      end

      it "does not process subscriptions not yet due" do
        described_class.perform_now
        expect(adapter).not_to have_received(:create_charge)
      end
    end

    context "when subscription is cancelled" do
      before do
        subscription.update!(status: "cancelled", cancelled_at: Time.current)
        allow(adapter).to receive(:create_charge)
      end

      it "does not process cancelled subscriptions" do
        described_class.perform_now
        expect(adapter).not_to have_received(:create_charge)
      end
    end

    context "when subscription is past_due and vencida" do
      before do
        subscription.update!(status: "past_due")
        allow(adapter).to receive(:create_charge).and_return({
          "id"          => "pay_pastdue_456",
          "status"      => "PENDING",
          "billingType" => "UNDEFINED",
          "invoiceUrl"  => nil
        })
      end

      it "still tries to renew past_due subscriptions" do
        described_class.perform_now
        expect(adapter).to have_received(:create_charge)
      end
    end

    context "when gateway raises an error" do
      before do
        allow(adapter).to receive(:create_charge)
          .and_raise(Gateways::Base::GatewayError.new("Payment failed", code: 400))
      end

      it "marks subscription as past_due" do
        described_class.perform_now
        subscription.reload
        expect(subscription.status).to eq("past_due")
      end

      it "dispatches payment.failed webhook" do
        described_class.perform_now

        expect(WebhookDispatchJob).to have_received(:perform_later).with(
          customer,
          "payment.failed",
          hash_including(gateway: "asaas", reason: "Payment failed")
        )
      end

      it "does not create a charge record" do
        expect { described_class.perform_now }.not_to change(Charge, :count)
      end
    end

    context "billing_type determination" do
      before do
        allow(adapter).to receive(:create_charge).and_return({
          "id"          => "pay_bt_789",
          "status"      => "PENDING",
          "billingType" => "PIX",
          "invoiceUrl"  => nil
        })
      end

      it "uses UNDEFINED when no previous paid charge exists" do
        described_class.perform_now

        expect(adapter).to have_received(:create_charge).with(
          customer, 9900,
          hash_including(billing_type: "UNDEFINED")
        )
      end

      it "uses the billing_type from the last paid charge" do
        create(:charge,
               customer:          customer,
               subscription:      subscription,
               gateway:           "asaas",
               status:            "paid",
               paid_at:           1.day.ago,
               charge_data:       { "billing_type" => "BOLETO" })

        described_class.perform_now

        expect(adapter).to have_received(:create_charge).with(
          customer, 9900,
          hash_including(billing_type: "BOLETO")
        )
      end
    end
    context "when subscription has product_packs in metadata" do
      before do
        subscription.update!(metadata: { "product_packs" => { "42" => 2 } })
        allow(adapter).to receive(:create_charge).and_return({
          "id" => "pay_pack_1", "status" => "PENDING", "billingType" => "PIX", "invoiceUrl" => nil
        })
      end

      it "passa product_packs ao Pricing::CalculateService" do
        described_class.perform_now

        expect(Pricing::CalculateService).to have_received(:call)
          .with(hash_including(product_packs: { "42" => 2 }))
      end
    end
    context "when subscription has a scheduled plan change (downgrade)" do
      let(:cheaper_plan) do
        p = create(:plan, account: account, name: "Basic")
        create(:plan_price, plan: p, currency: currency, amount_cents: 4_900)
        p
      end

      before do
        subscription.update!(
          metadata: { "scheduled_plan_change" => { "plan_id" => cheaper_plan.id } }
        )
        allow(adapter).to receive(:update_subscription)
        allow(adapter).to receive(:create_charge).and_return({
          "id" => "pay_dg_1", "status" => "PENDING", "billingType" => "PIX", "invoiceUrl" => nil
        })
      end

      it "aplica o downgrade e limpa o agendamento antes de renovar" do
        described_class.perform_now

        subscription.reload
        expect(subscription.plan_id).to eq(cheaper_plan.id)
        expect(subscription.metadata["scheduled_plan_change"]).to be_nil
      end
    end
  end

  describe "queue" do
    it "uses the billing queue" do
      expect(described_class.new.queue_name).to eq("billing")
    end
  end
end

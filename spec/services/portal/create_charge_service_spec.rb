require "rails_helper"

RSpec.describe Portal::CreateChargeService do
  let(:account)      { create(:account) }
  let(:integration)  { create(:integration, account: account) }
  let(:currency)     { create(:currency, account: account, code: "BRL", default: true) }
  let(:customer)     { create(:customer, account: account, currency: currency) }
  let(:credit_type)  { create(:credit_type, account: account, key: "tokens") }
  let(:plan)         { create(:plan, account: account) }
  let(:subscription) do
    create(:subscription,
           customer:    customer,
           plan:        plan,
           integration: integration,
           gateway:     "asaas",
           status:      "active")
  end
  let(:product) do
    create(:product,
           account:         account,
           product_type:    "credit_pack",
           credit_type:     credit_type,
           credit_quantity: 1000)
  end
  let(:product_price) do
    create(:product_price, product: product, currency: currency, amount_cents: 5000)
  end

  before do
    set_tenant(account)
    product_price # ensure it's created with tenant set
    subscription  # ensure it's created
  end

  after { ActsAsTenant.current_tenant = nil }

  describe ".call" do
    let(:gateway_result) do
      {
        "id"             => "chr_abc123",
        "pix_qr_code"    => "base64qrcode",
        "pix_copy_paste" => "00020126...",
        "redirect_url"   => nil
      }
    end

    before do
      adapter = double("AsaasAdapter")
      allow(Gateways::Base).to receive(:for).with("asaas").and_return(adapter)
      allow(adapter).to receive(:create_charge).and_return(gateway_result)
    end

    it "creates a charge with pending status" do
      charge = described_class.call(
        customer:    customer,
        product:     product,
        integration: integration,
        gateway:     "asaas"
      )

      expect(charge).to be_persisted
      expect(charge.status).to eq("pending")
      expect(charge.amount_cents).to eq(5000)
      expect(charge.gateway_charge_id).to eq("chr_abc123")
    end

    it "stores pix data in charge_data" do
      charge = described_class.call(
        customer:    customer,
        product:     product,
        integration: integration,
        gateway:     "asaas"
      )

      expect(charge.charge_data["pix_qr_code"]).to eq("base64qrcode")
      expect(charge.charge_data["pix_copy_paste"]).to eq("00020126...")
    end

    it "stores pending_credit info for post-payment processing" do
      charge = described_class.call(
        customer:    customer,
        product:     product,
        integration: integration,
        gateway:     "asaas"
      )

      expect(charge.charge_data["pending_credit"]["credit_type_id"]).to eq(credit_type.id)
      expect(charge.charge_data["pending_credit"]["quantity"]).to eq(1000)
    end
  end
end

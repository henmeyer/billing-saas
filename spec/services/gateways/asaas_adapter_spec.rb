require "rails_helper"

RSpec.describe Gateways::AsaasAdapter, type: :service do
  let(:account) { create(:account) }
  let(:payment_gateway) { create(:payment_gateway, account: account, provider: "asaas") }
  let(:customer) { create(:customer, account: account, gateway_data: { "asaas" => { "customer_id" => "cus_abc123" } }) }
  let(:plan) { create(:plan, account: account) }

  before do
    set_tenant(account)
    payment_gateway # force creation after tenant is set
  end

  subject(:adapter) { described_class.new }

  describe "#initialize" do
    it "loads the Asaas gateway for the current tenant" do
      expect { adapter }.not_to raise_error
    end

    it "raises if no Asaas gateway is configured" do
      payment_gateway.destroy
      expect { described_class.new }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "#create_customer" do
    let(:new_customer) { create(:customer, account: account, gateway_data: {}) }

    before do
      stub_request(:post, %r{/customers})
        .to_return(
          status: 200,
          body: { "id" => "cus_new_123", "name" => new_customer.name }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "creates a customer on Asaas and saves the customer_id" do
      result = adapter.create_customer(new_customer)

      expect(result["id"]).to eq("cus_new_123")
      new_customer.reload
      expect(new_customer.gateway_data.dig("asaas", "customer_id")).to eq("cus_new_123")
    end

    context "when customer already has an asaas customer_id" do
      let(:existing_customer) { create(:customer, account: account, gateway_data: { "asaas" => { "customer_id" => "cus_existing" } }) }

      before do
        stub_request(:get, %r{/customers/cus_existing})
          .to_return(
            status: 200,
            body: { "id" => "cus_existing", "name" => existing_customer.name }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "fetches the existing customer instead of creating" do
        result = adapter.create_customer(existing_customer)
        expect(result["id"]).to eq("cus_existing")
      end
    end
  end

  describe "#create_subscription (billing-managed)" do
    before do
      stub_request(:post, %r{/payments})
        .to_return(
          status: 200,
          body: {
            "id" => "pay_123",
            "status" => "PENDING",
            "invoiceUrl" => "https://asaas.com/invoice/123",
            "billingType" => "PIX"
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:get, %r{/payments/pay_123/pixQrCode})
        .to_return(
          status: 200,
          body: {
            "encodedImage" => "base64qrcode",
            "payload" => "pix-copy-paste-code",
            "expirationDate" => "2026-06-30"
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "creates a charge (not a native subscription) and returns an OpenStruct" do
      result = adapter.create_subscription(customer, plan, amount_cents: 5000, billing_type: "PIX")

      expect(result).to respond_to(:id)
      expect(result).to respond_to(:payment_id)
      expect(result.payment_id).to eq("pay_123")
      expect(result.redirect_url).to be_nil
      expect(result.status).to eq("PENDING")
      expect(result.id).to start_with("sub_")
    end

    it "includes pix data when billing_type is PIX" do
      result = adapter.create_subscription(customer, plan, amount_cents: 5000, billing_type: "PIX")

      expect(result.pix).to be_present
      expect(result.pix[:qr_code]).to eq("base64qrcode")
      expect(result.pix[:copy_paste]).to eq("pix-copy-paste-code")
    end

    it "includes invoice_url" do
      result = adapter.create_subscription(customer, plan, amount_cents: 5000, billing_type: "BOLETO")
      expect(result.invoice_url).to eq("https://asaas.com/invoice/123")
    end
  end

  describe "#create_subscription_legacy (gateway-managed)" do
    before do
      stub_request(:post, %r{/subscriptions})
        .to_return(
          status: 200,
          body: { "id" => "sub_asaas_native_123", "status" => "ACTIVE" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "creates a native Asaas subscription" do
      result = adapter.create_subscription_legacy(customer, plan)

      expect(result["id"]).to eq("sub_asaas_native_123")
      expect(a_request(:post, %r{/subscriptions})).to have_been_made.once
    end
  end

  describe "#cancel_subscription" do
    context "when gateway-managed (native Asaas sub)" do
      before do
        stub_request(:delete, %r{/subscriptions/sub_asaas_native_123})
          .to_return(
            status: 200,
            body: { "deleted" => true, "id" => "sub_asaas_native_123" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "calls DELETE on the Asaas subscription" do
        result = adapter.cancel_subscription("sub_asaas_native_123")
        expect(result["deleted"]).to be true
        expect(a_request(:delete, %r{/subscriptions/sub_asaas_native_123})).to have_been_made.once
      end
    end

    context "when billing-managed (sub_ID_TIMESTAMP format)" do
      it "is a noop — does not call the Asaas API" do
        result = adapter.cancel_subscription("sub_42_1700000000")
        expect(result).to eq({})
      end
    end

    context "when gateway_sub_id is blank" do
      it "is a noop" do
        expect(adapter.cancel_subscription(nil)).to eq({})
        expect(adapter.cancel_subscription("")).to eq({})
      end
    end
  end

  describe "#update_subscription" do
    context "when gateway-managed" do
      before do
        stub_request(:put, %r{/subscriptions/sub_asaas_native_456})
          .to_return(
            status: 200,
            body: { "id" => "sub_asaas_native_456", "value" => 99.90 }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "calls PUT on the Asaas subscription" do
        result = adapter.update_subscription("sub_asaas_native_456", plan, amount_cents: 9990)
        expect(result["id"]).to eq("sub_asaas_native_456")
        expect(a_request(:put, %r{/subscriptions/sub_asaas_native_456})).to have_been_made.once
      end
    end

    context "when billing-managed (sub_ID_TIMESTAMP format)" do
      it "is a noop" do
        result = adapter.update_subscription("sub_42_1700000000", plan, amount_cents: 5000)
        expect(result).to eq({})
      end
    end
  end

  describe "#create_charge" do
    before do
      stub_request(:post, %r{/payments})
        .to_return(
          status: 200,
          body: {
            "id" => "pay_456",
            "status" => "PENDING",
            "billingType" => "BOLETO",
            "dueDate" => "2026-06-27",
            "invoiceUrl" => "https://asaas.com/invoice/456"
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "creates an avulsa payment on Asaas" do
      result = adapter.create_charge(customer, 5000, description: "Test charge")

      expect(result["id"]).to eq("pay_456")
      expect(result["status"]).to eq("PENDING")
      expect(a_request(:post, %r{/payments})).to have_been_made.once
    end

    it "uses 3 days from now as default due_date" do
      adapter.create_charge(customer, 5000)

      expect(a_request(:post, %r{/payments}).with { |req|
        body = JSON.parse(req.body)
        body["dueDate"] == 3.days.from_now.strftime("%Y-%m-%d")
      }).to have_been_made.once
    end

    context "when billing_type is PIX" do
      before do
        stub_request(:get, %r{/payments/pay_456/pixQrCode})
          .to_return(
            status: 200,
            body: {
              "encodedImage" => "base64pix",
              "payload" => "pix-code"
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "fetches pix QR code data and merges into result" do
        result = adapter.create_charge(customer, 5000, billing_type: "PIX")

        expect(result["encodedImage"]).to eq("base64pix")
        expect(result["payload"]).to eq("pix-code")
      end
    end
  end

  describe "#get_pix_data" do
    before do
      stub_request(:get, %r{/payments/pay_789/pixQrCode})
        .to_return(
          status: 200,
          body: { "encodedImage" => "qr_base64", "payload" => "copy-paste" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns pix QR code data" do
      result = adapter.get_pix_data("pay_789")
      expect(result["encodedImage"]).to eq("qr_base64")
      expect(result["payload"]).to eq("copy-paste")
    end
  end

  describe "#get_boleto_data" do
    before do
      stub_request(:get, %r{/payments/pay_789/identificationField})
        .to_return(
          status: 200,
          body: { "identificationField" => "23793.38128 00000.000124", "nossoNumero" => "12345" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns boleto identification field" do
      result = adapter.get_boleto_data("pay_789")
      expect(result["identificationField"]).to be_present
    end
  end

  describe "#create_refund" do
    before do
      stub_request(:post, %r{/payments/pay_789/refund})
        .to_return(
          status: 200,
          body: { "id" => "refund_123", "status" => "PENDING" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "creates a refund for the payment" do
      result = adapter.create_refund("pay_789")
      expect(result["id"]).to eq("refund_123")
    end

    it "passes amount_cents when provided" do
      adapter.create_refund("pay_789", amount_cents: 2500)

      expect(a_request(:post, %r{/payments/pay_789/refund}).with { |req|
        body = JSON.parse(req.body)
        body["value"] == 25.0
      }).to have_been_made.once
    end
  end

  describe "#get_payment" do
    before do
      stub_request(:get, %r{/payments/pay_999})
        .to_return(
          status: 200,
          body: { "id" => "pay_999", "status" => "RECEIVED", "value" => 50.0 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "fetches payment details" do
      result = adapter.get_payment("pay_999")
      expect(result["id"]).to eq("pay_999")
      expect(result["status"]).to eq("RECEIVED")
    end
  end

  describe "#test_connection" do
    context "when successful" do
      before do
        stub_request(:get, %r{/finance/balance})
          .to_return(
            status: 200,
            body: { "balance" => 1000.0 }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns success" do
        result = adapter.test_connection
        expect(result[:success]).to be true
        expect(result[:message]).to eq("Conexão com Asaas OK")
      end
    end

    context "when authentication fails" do
      before do
        stub_request(:get, %r{/finance/balance})
          .to_return(status: 401, body: "Unauthorized")
      end

      it "returns failure" do
        result = adapter.test_connection
        expect(result[:success]).to be false
      end
    end
  end

  describe "error handling" do
    it "raises GatewayError with details on API failure" do
      stub_request(:post, %r{/payments})
        .to_return(
          status: 400,
          body: { "errors" => [{ "description" => "Value is required" }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect {
        adapter.create_charge(customer, 0)
      }.to raise_error(Gateways::Base::GatewayError, /Value is required/)
    end
  end
end

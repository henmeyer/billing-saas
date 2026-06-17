require "rails_helper"

RSpec.describe Webhooks::TestService do
  let(:account) { create(:account) }
  let(:integration) do
    create(:integration, account: account,
                         url:     "https://exemplo.com/webhook",
                         secret:  "test_secret_123",
                         events:  ["payment.received", "credits.depleted"])
  end

  before { set_tenant(account) }
  after  { ActsAsTenant.current_tenant = nil }

  describe ".call" do
    context "servidor responde com sucesso" do
      before do
        stub_request(:post, "https://exemplo.com/webhook")
          .to_return(status: 200, body: '{"ok":true}')
      end

      it "retorna success? true com status_code 200" do
        result = described_class.call(integration: integration, event: "payment.received")
        expect(result.success?).to be true
        expect(result.status_code).to eq(200)
      end

      it "inclui header X-Webhook-Test: true" do
        described_class.call(integration: integration, event: "payment.received")
        expect(WebMock).to have_requested(:post, "https://exemplo.com/webhook")
          .with(headers: { "X-Webhook-Test" => "true" })
      end

      it "inclui flag test: true no payload" do
        described_class.call(integration: integration, event: "payment.received")
        expect(WebMock).to(have_requested(:post, "https://exemplo.com/webhook")
          .with { |req| JSON.parse(req.body)["test"] == true })
      end

      it "assina o payload com HMAC-SHA256" do
        described_class.call(integration: integration, event: "payment.received")
        expect(WebMock).to(have_requested(:post, "https://exemplo.com/webhook")
          .with { |req|
            expected = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", "test_secret_123", req.body)}"
            req.headers["X-Billing-Signature"] == expected
          })
      end

      it "retorna duration_ms positivo" do
        result = described_class.call(integration: integration, event: "payment.received")
        expect(result.duration_ms).to be >= 0
      end
    end

    context "servidor responde com erro" do
      before do
        stub_request(:post, "https://exemplo.com/webhook")
          .to_return(status: 500, body: "Internal Server Error")
      end

      it "retorna success? false com status_code" do
        result = described_class.call(integration: integration, event: "payment.received")
        expect(result.success?).to be false
        expect(result.status_code).to eq(500)
      end
    end

    context "timeout" do
      before do
        stub_request(:post, "https://exemplo.com/webhook").to_timeout
      end

      it "retorna success? false com mensagem de timeout" do
        result = described_class.call(integration: integration, event: "payment.received")
        expect(result.success?).to be false
        expect(result.error).to include("Timeout")
      end
    end

    it "inclui dados realistas no payload do evento credits.depleted" do
      stub_request(:post, "https://exemplo.com/webhook").to_return(status: 200)

      described_class.call(integration: integration, event: "credits.depleted")

      expect(WebMock).to(have_requested(:post, "https://exemplo.com/webhook")
        .with { |req|
          data = JSON.parse(req.body)["data"]
          data["credit_type"] == "coins" && data["usage_percent"] == 100.0
        })
    end
  end
end

require "rails_helper"

RSpec.describe WebhookDispatchJob do
  let(:account)     { create(:account) }
  let(:customer)    { create(:customer, account: account) }
  let(:integration) do
    create(:integration,
      account: account,
      events:  ["payment.received"],
      url:     "https://example.com/hook"
    )
  end

  before { ActsAsTenant.current_tenant = account }
  after  { ActsAsTenant.current_tenant = nil }

  describe "entrega com sucesso" do
    before do
      allow(HTTParty).to receive(:post).and_return(
        double(success?: true, code: 200, body: "ok")
      )
    end

    it "cria um WebhookLog com status delivered" do
      described_class.perform_now(customer, "payment.received", {})
      log = WebhookLog.last
      expect(log.status).to eq("delivered")
      expect(log.event).to eq("payment.received")
    end

    it "envia o header X-Billing-Signature" do
      expect(HTTParty).to receive(:post).with(
        integration.url,
        hash_including(headers: hash_including("X-Billing-Signature" => /^sha256=/))
      ).and_return(double(success?: true))
      described_class.perform_now(customer, "payment.received", {})
    end
  end

  describe "quando o endpoint falha" do
    before do
      allow(HTTParty).to receive(:post).and_return(
        double(success?: false, code: 500, body: "internal error")
      )
    end

    it "cria log com next_retry_at e enfileira retry" do
      described_class.perform_now(customer, "payment.received", {})
      log = WebhookLog.last
      expect(log.status).to eq("pending")
      expect(log.next_retry_at).to be_present
    end
  end

  describe "quando nenhuma integração cobre o evento" do
    it "não cria WebhookLog" do
      expect {
        described_class.perform_now(customer, "evento.desconhecido", {})
      }.not_to change(WebhookLog, :count)
    end
  end

  describe "após 5 tentativas falhas" do
    before do
      allow(HTTParty).to receive(:post).and_return(
        double(success?: false, code: 503, body: "unavailable")
      )
    end

    it "marca o log como failed na última tentativa" do
      described_class.perform_now(customer, "payment.received", {}, attempt: 5)
      expect(WebhookLog.last.status).to eq("failed")
    end
  end
end

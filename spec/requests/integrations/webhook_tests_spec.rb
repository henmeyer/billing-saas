require "rails_helper"

RSpec.describe "Integrations::WebhookTests", type: :request do
  let(:account) { create(:account) }
  let(:user)    { create(:user) }
  let(:integration) do
    create(:integration, account: account,
                         url:     "https://exemplo.com/webhook",
                         events:  ["payment.received"])
  end

  before do
    create(:account_user, account: account, user: user, role: "admin")
    sign_in user
    set_tenant(account)
  end

  after { ActsAsTenant.current_tenant = nil }

  describe "POST /integrations/:integration_id/webhook_tests" do
    it "dispara o teste e retorna resultado de sucesso" do
      stub_request(:post, "https://exemplo.com/webhook")
        .to_return(status: 200, body: "ok")

      post "/integrations/#{integration.id}/webhook_tests",
           params: { event: "payment.received" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["status_code"]).to eq(200)
    end

    it "rejeita evento inválido" do
      post "/integrations/#{integration.id}/webhook_tests",
           params: { event: "evento.inexistente" }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Evento inválido")
    end
  end

  describe "GET /integrations/:integration_id/webhook_tests/logs" do
    it "retorna histórico de testes (vazio inicialmente)" do
      get "/integrations/#{integration.id}/webhook_tests/logs"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to have_key("logs")
      expect(json["logs"]).to be_an(Array)
    end

    context "com logs de teste existentes" do
      let(:customer) { create(:customer, account: account) }

      before do
        create(:webhook_log,
               integration:   integration,
               customer:      customer,
               event:         "payment.received",
               status:        "delivered",
               is_test:       true,
               response_code: 200,
               duration_ms:   150)
      end

      it "retorna os logs de teste" do
        get "/integrations/#{integration.id}/webhook_tests/logs"

        json = JSON.parse(response.body)
        expect(json["logs"].length).to eq(1)
        expect(json["logs"].first["event"]).to eq("payment.received")
        expect(json["logs"].first["status"]).to eq("delivered")
      end
    end
  end
end

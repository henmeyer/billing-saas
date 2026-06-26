require "rails_helper"

RSpec.describe "Webhooks::Asaas", type: :request do
  let(:secret) { "test_asaas_secret" }

  before { stub_const("ENV", ENV.to_hash.merge("ASAAS_WEBHOOK_SECRET" => secret)) }

  def post_with_valid_sig(payload)
    post "/webhooks/asaas",
         params:  payload.to_json,
         headers: {
           "Content-Type"       => "application/json",
           "asaas-access-token" => secret
         }
  end

  describe "POST /webhooks/asaas" do
    context "com assinatura válida" do
      it "enfileira o job e retorna 200" do
        expect(Webhooks::ProcessAsaasEventJob).to receive(:perform_later)
          .with("payment_received", anything)

        post_with_valid_sig({ "event" => "PAYMENT_RECEIVED", "payment" => {} })
        expect(response).to have_http_status(:ok)
      end

      it "ignora eventos desconhecidos sem erro" do
        expect(Webhooks::ProcessAsaasEventJob).not_to receive(:perform_later)
        post_with_valid_sig({ "event" => "UNKNOWN_EVENT" })
        expect(response).to have_http_status(:ok)
      end
    end

    context "com assinatura inválida" do
      it "retorna 401" do
        post "/webhooks/asaas",
             params:  { event: "PAYMENT_RECEIVED" }.to_json,
             headers: {
               "Content-Type"       => "application/json",
               "asaas-access-token" => "sha256=invalida"
             }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end

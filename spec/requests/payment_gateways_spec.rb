require "rails_helper"

RSpec.describe "PaymentGateways", type: :request do
  let(:account) { create(:account) }
  let(:user)    { create(:user) }
  let(:gateway) { create(:payment_gateway, account: account, provider: "asaas") }

  before do
    create(:account_user, account: account, user: user, role: "admin")
    sign_in user
    set_tenant(account)
  end

  after { ActsAsTenant.current_tenant = nil }

  describe "POST /payment_gateways/:id/test" do
    let(:adapter) { instance_double(Gateways::AsaasAdapter) }

    before do
      allow(Gateways::Base).to receive(:for).with("asaas").and_return(adapter)
    end

    # Liga a proteção CSRF (desabilitada por padrão no ambiente de teste) para
    # garantir que a action #test não falha com InvalidAuthenticityToken quando
    # o request não envia o token (caso do fetch AJAX no contexto Inertia).
    around do |example|
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      example.run
      ActionController::Base.allow_forgery_protection = original
    end

    it "succeeds without a CSRF token and returns the adapter result" do
      allow(adapter).to receive(:test_connection)
        .and_return({ success: true, message: "Conexão OK" })

      post test_payment_gateway_path(gateway),
           params:  {}.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["success"]).to be true
      expect(body["message"]).to eq("Conexão OK")
    end

    it "returns a failure payload when the adapter raises" do
      allow(adapter).to receive(:test_connection).and_raise(StandardError, "credenciais inválidas")

      post test_payment_gateway_path(gateway),
           params:  {}.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["success"]).to be false
      expect(body["message"]).to eq("credenciais inválidas")
    end
  end
end

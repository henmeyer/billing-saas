require "rails_helper"

RSpec.describe "Api::V1::Credits", type: :request do
  let(:account)     { create(:account) }
  let(:integration) { create(:integration, account: account) }
  let(:customer)    { create(:customer, account: account) }
  let(:plan)        { create(:plan, account: account) }
  let(:sub)         { create(:subscription, customer: customer, plan: plan, integration: integration) }
  let(:period)      { create(:subscription_period, subscription: sub) }
  let(:credit_type) { create(:credit_type, account: account, key: "api_calls") }

  let(:raw_token) do
    _, token = IntegrationApiKey.generate!(integration: integration, name: "test")
    token
  end

  before do
    set_tenant(account)
    customer.set_identity!(integration: integration, external_id: "EXT001")
  end

  after { ActsAsTenant.current_tenant = nil }

  let(:headers) { { "Authorization" => "Bearer #{raw_token}" } }

  describe "GET /api/v1/customers/:external_id/credits" do
    context "com snapshot existente" do
      before do
        create(:credit_snapshot,
               subscription_period: period,
               credit_type:         credit_type,
               used: 300, limit: 1000)
      end

      it "retorna o saldo de créditos" do
        get "/api/v1/customers/EXT001/credits", headers: headers
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["credits"]["api_calls"]["used"]).to eq(300)
        expect(json["credits"]["api_calls"]["limit"]).to eq(1000)
        expect(json["credits"]["api_calls"]["balance"]).to eq(700)
      end
    end

    context "sem assinatura ativa" do
      let(:customer2) { create(:customer, account: account) }

      before do
        customer2.set_identity!(integration: integration, external_id: "EXT002")
      end

      it "retorna 422" do
        get "/api/v1/customers/EXT002/credits", headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "cliente inexistente" do
      it "retorna 404" do
        get "/api/v1/customers/NAOEXISTE/credits", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /api/v1/customers/:external_id/credits/report" do
    before do
      sub
      period
      credit_type
    end

    it "cria ou atualiza o snapshot" do
      post "/api/v1/customers/EXT001/credits/report",
           params:  { credit_type: "api_calls", used: 500 },
           headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["balance"]).to eq(0)
      snapshot = period.credit_snapshots.find_by(credit_type: credit_type)
      expect(snapshot.used).to eq(500)
    end

    it "retorna 404 para credit_type inexistente" do
      post "/api/v1/customers/EXT001/credits/report",
           params:  { credit_type: "inexistente", used: 100 },
           headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end
end

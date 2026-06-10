require "rails_helper"

RSpec.describe "Api::V1::Subscriptions", type: :request do
  let(:account)     { create(:account) }
  let(:integration) { create(:integration, account: account) }
  let(:currency)    { create(:currency, account: account, default: true) }
  let(:plan)        { create(:plan, account: account, name: "Pro") }
  let(:customer)    { create(:customer, account: account) }

  before { set_tenant(account) }
  after  { ActsAsTenant.current_tenant = nil }

  let(:raw_token) { "billing_int_#{SecureRandom.hex(32)}" }

  let!(:integration_api_key) do
    IntegrationApiKey.create!(
      integration:  integration,
      name:         "test",
      token_digest: Digest::SHA256.hexdigest(raw_token),
      last_four:    raw_token.last(4),
      active:       true
    )
  end

  let!(:customer_identity) do
    CustomerIdentity.create!(
      customer:    customer,
      integration: integration,
      external_id: "EXT001"
    )
  end

  let!(:subscription) do
    create(:subscription,
           customer:    customer,
           plan:        plan,
           integration: integration,
           currency:    currency)
  end

  before { create(:plan_price, plan: plan, currency: currency, amount_cents: 9900) }

  let(:headers) { { "Authorization" => "Bearer #{raw_token}" } }

  describe "GET /api/v1/customers/:external_id/subscription" do
    it "retorna os dados da assinatura ativa com integration_id e integration_name" do
      get "/api/v1/customers/EXT001/subscription", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["plan"]["name"]).to eq("Pro")
      expect(json["plan"]["price_cents"]).to eq(9900)
      expect(json["status"]).to eq("active")
      expect(json["integration_id"]).to eq(integration.id)
      expect(json["integration_name"]).to eq(integration.name)
    end

    it "retorna 404 para cliente sem assinatura na integração" do
      other_customer = create(:customer, account: account)
      CustomerIdentity.create!(
        customer:    other_customer,
        integration: integration,
        external_id: "EXT002"
      )

      get "/api/v1/customers/EXT002/subscription", headers: headers

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]).to include(integration.name)
    end

    context "com integration_id query param" do
      let(:other_integration) { create(:integration, account: account) }

      let!(:other_subscription) do
        create(:subscription,
               customer:    customer,
               plan:        plan,
               integration: other_integration,
               currency:    currency)
      end

      it "retorna a assinatura da integração especificada" do
        get "/api/v1/customers/EXT001/subscription",
            params:  { integration_id: other_integration.id },
            headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["integration_id"]).to eq(other_integration.id)
        expect(json["integration_name"]).to eq(other_integration.name)
      end

      it "retorna 404 se integration_id não existe" do
        get "/api/v1/customers/EXT001/subscription",
            params:  { integration_id: 999_999 },
            headers: headers

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Integração não encontrada")
      end

      it "retorna 404 se não há assinatura para a integração especificada" do
        empty_integration = create(:integration, account: account)

        get "/api/v1/customers/EXT001/subscription",
            params:  { integration_id: empty_integration.id },
            headers: headers

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]).to include(empty_integration.name)
      end
    end

    context "sem integration_id param (infer da API key)" do
      it "usa a integração da API key como padrão" do
        get "/api/v1/customers/EXT001/subscription", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["integration_id"]).to eq(integration.id)
      end
    end
  end
end

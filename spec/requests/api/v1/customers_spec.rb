require "rails_helper"

RSpec.describe "Api::V1::Customers", type: :request do
  let(:account)     { create(:account) }
  let(:integration) { create(:integration, account: account) }
  let(:currency)    { create(:currency, account: account, default: true) }

  before { set_tenant(account) }
  after  { ActsAsTenant.current_tenant = nil }

  let(:raw_token) { "#{IntegrationApiKey::PREFIX}#{SecureRandom.hex(32)}" }

  let!(:integration_api_key) do
    IntegrationApiKey.create!(
      integration:  integration,
      name:         "test",
      token_digest: Digest::SHA256.hexdigest(raw_token),
      last_four:    raw_token.last(4),
      active:       true
    )
  end

  let(:headers)       { { "Authorization" => "Bearer #{raw_token}" } }
  let(:valid_payload) do
    {
      external_id: "user_123",
      name:        "Acme Ltda",
      email:       "billing@acme.com",
      document:    "00.000.000/0001-00",
      country:     "BR",
      phone:       "+55 11 99999-9999"
    }
  end

  describe "POST /api/v1/customers" do
    context "cliente novo" do
      it "cria cliente e retorna 201" do
        post "/api/v1/customers", params: valid_payload, headers: headers

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["external_id"]).to eq("user_123")
        expect(json["email"]).to eq("billing@acme.com")
        expect(json["document"]).to eq("00.000.000/0001-00")
        expect(json["country"]).to eq("BR")
      end

      it "cria a CustomerIdentity vinculando ao external_id" do
        post "/api/v1/customers", params: valid_payload, headers: headers

        ActsAsTenant.with_tenant(account) do
          identity = CustomerIdentity.find_by(integration: integration, external_id: "user_123")
          expect(identity).to be_present
          expect(identity.customer.email).to eq("billing@acme.com")
        end
      end
    end

    context "external_id já existe para esta integração (idempotente)" do
      before do
        ActsAsTenant.with_tenant(account) do
          customer = create(:customer, account: account, email: "billing@acme.com",
                            document: "00.000.000/0001-00")
          customer.set_identity!(integration: integration, external_id: "user_123")
        end
      end

      it "retorna 200 sem criar duplicata" do
        initial = ActsAsTenant.with_tenant(account) { Customer.count }
        post "/api/v1/customers", params: valid_payload, headers: headers
        expect(ActsAsTenant.with_tenant(account) { Customer.count }).to eq(initial)

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["external_id"]).to eq("user_123")
      end
    end

    context "e-mail já existe na conta sem identity" do
      before do
        ActsAsTenant.with_tenant(account) do
          create(:customer, account: account, email: "billing@acme.com",
                 document: "00.000.000/0001-00")
        end
      end

      it "vincula o external_id ao cliente existente sem criar novo" do
        initial = ActsAsTenant.with_tenant(account) { Customer.count }
        post "/api/v1/customers", params: valid_payload, headers: headers
        expect(ActsAsTenant.with_tenant(account) { Customer.count }).to eq(initial)

        expect(response).to have_http_status(:created)
        ActsAsTenant.with_tenant(account) do
          expect(CustomerIdentity.find_by(integration: integration, external_id: "user_123")).to be_present
        end
      end
    end

    context "dados inválidos" do
      it "retorna 422 sem nome" do
        post "/api/v1/customers",
             params:  valid_payload.merge(name: ""),
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["errors"]).to be_present
      end

      it "retorna 422 sem documento" do
        post "/api/v1/customers",
             params:  valid_payload.merge(document: ""),
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it "retorna 401 sem token" do
      post "/api/v1/customers", params: valid_payload
      expect(response).to have_http_status(:unauthorized)
    end
  end
end

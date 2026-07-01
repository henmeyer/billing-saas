require "swagger_helper"

RSpec.describe "API de Clientes", type: :request do
  let(:account)     { create(:account) }
  let(:integration) { create(:integration, account: account) }

  let(:raw_token) do
    _key, token = IntegrationApiKey.generate!(integration: integration, name: "swagger-test")
    token
  end

  before { set_tenant(account) }
  after  { ActsAsTenant.current_tenant = nil }

  let(:Authorization) { "Bearer #{raw_token}" }

  path "/api/v1/customers" do
    post "Criar ou recuperar cliente" do
      tags        "Clientes"
      security    [{ BearerAuth: [] }]
      consumes    "application/json"
      produces    "application/json"
      description <<~DESC
        Cria um cliente e vincula ao `external_id` da sua integração.

        **Idempotente:** se o `external_id` já estiver cadastrado para esta integração,
        retorna o cliente existente com status `200` sem criar duplicata.

        Se o e-mail já existir em outro cliente da conta, o `external_id` é vinculado
        a esse cliente (útil para clientes com múltiplas integrações).
      DESC

      parameter name: :body, in: :body, required: true,
                schema: { "$ref" => "#/components/schemas/CustomerCreateRequest" }

      response "201", "Cliente criado" do
        schema "$ref" => "#/components/schemas/CustomerResponse"

        let(:body) do
          {
            external_id: "user_abc123",
            name:        "Acme Ltda",
            email:       "billing@acme.com",
            document:    "00.000.000/0001-00",
            phone:       "+55 11 99999-9999",
            country:     "BR"
          }
        end

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["external_id"]).to eq("user_abc123")
          expect(json["email"]).to eq("billing@acme.com")
        end
      end

      response "200", "Cliente já existia (idempotente)" do
        schema "$ref" => "#/components/schemas/CustomerResponse"

        before do
          customer = create(:customer, account: account, email: "billing@acme.com",
                            document: "00.000.000/0001-00")
          customer.set_identity!(integration: integration, external_id: "user_abc123")
        end

        let(:body) do
          {
            external_id: "user_abc123",
            name:        "Acme Ltda",
            email:       "billing@acme.com",
            document:    "00.000.000/0001-00"
          }
        end

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["external_id"]).to eq("user_abc123")
        end
      end

      response "401", "Token inválido" do
        schema "$ref" => "#/components/schemas/Error"
        let(:Authorization) { "Bearer invalido" }
        let(:body) { { external_id: "x", name: "x", email: "x@x.com", document: "123" } }
        run_test!
      end

      response "422", "Dados inválidos" do
        schema do
          {
            type:       "object",
            properties: {
              errors: {
                type:        "object",
                description: "Mapa de campo → lista de erros"
              }
            }
          }
        end

        let(:body) { { external_id: "user_abc123", name: "", email: "invalido", document: "" } }
        run_test!
      end
    end
  end
end

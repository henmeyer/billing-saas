require "swagger_helper"

RSpec.describe "API de Assinatura", type: :request do
  let(:account)      { create(:account) }
  let(:integration)  { create(:integration, account: account) }
  let(:customer)     { create(:customer, account: account) }
  let(:plan)         { create(:plan, account: account, name: "Pro") }
  let(:currency)     { create(:currency, account: account) }
  let(:subscription) { create(:subscription, customer: customer, plan: plan, integration: integration, currency: currency) }

  let(:raw_token) do
    _key, token = IntegrationApiKey.generate!(integration: integration, name: "swagger-test")
    token
  end

  before do
    set_tenant(account)
    customer.set_identity!(integration: integration, external_id: "EXT123")
    create(:plan_price, plan: plan, currency: currency, amount_cents: 19_700)
    subscription
  end

  after { ActsAsTenant.current_tenant = nil }

  let(:Authorization) { "Bearer #{raw_token}" }

  path "/api/v1/customers/{external_id}/subscription" do
    parameter name: :external_id, in: :path, type: :string,
              required: true, example: "EXT123"

    get "Consultar assinatura ativa" do
      tags        "Assinatura"
      security    [{ BearerAuth: [] }]
      produces    "application/json"
      description <<~DESC
        Retorna os dados da assinatura ativa do cliente, incluindo
        plano, status, moeda e data de renovação.

        Use este endpoint para verificar se um cliente tem acesso ativo
        antes de permitir operações no seu sistema.
      DESC

      response "200", "Assinatura retornada com sucesso" do
        schema "$ref" => "#/components/schemas/SubscriptionResponse"
        let(:external_id) { "EXT123" }
        run_test!
      end

      response "401", "Token inválido" do
        schema "$ref" => "#/components/schemas/Error"
        let(:Authorization) { "Bearer invalido" }
        let(:external_id)   { "EXT123" }
        run_test!
      end

      response "404", "Sem assinatura ativa" do
        schema "$ref" => "#/components/schemas/Error"
        let(:external_id) { "EXT123" }
        before { subscription.update!(status: "cancelled") }
        run_test!
      end
    end

    post "Criar assinatura (trial ou ativa)" do
      tags        "Assinatura"
      security    [{ BearerAuth: [] }]
      consumes    "application/json"
      produces    "application/json"
      description <<~DESC
        Cria uma assinatura para o cliente, gerenciada pelo billing (sem gateway de pagamento).

        **Trial:** informe `trial_ends_at` para iniciar em período de teste.
        A assinatura fica com status `trialing` até a data informada.
        Após a data, use o portal do cliente ou o fluxo de conversão para ativar.

        **Ativa imediatamente:** omita `trial_ends_at` para criar já com status `active`.

        Um cliente pode ter apenas uma assinatura ativa por integração.
      DESC

      parameter name: :body, in: :body, required: true,
                schema: { "$ref" => "#/components/schemas/SubscriptionCreateRequest" }

      response "201", "Assinatura criada" do
        schema "$ref" => "#/components/schemas/SubscriptionCreateResponse"

        let(:external_id) { "EXT123" }
        let(:body) do
          { plan_id: plan.id, trial_ends_at: 14.days.from_now.iso8601 }
        end

        before { subscription.update!(status: "cancelled") }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["status"]).to eq("trialing")
          expect(json["managed_by"]).to eq("billing")
          expect(json["trial_ends_at"]).to be_present
        end
      end

      response "401", "Token inválido" do
        schema "$ref" => "#/components/schemas/Error"
        let(:Authorization) { "Bearer invalido" }
        let(:external_id)   { "EXT123" }
        let(:body)          { { plan_id: 1 } }
        run_test!
      end

      response "404", "Cliente ou plano não encontrado" do
        schema "$ref" => "#/components/schemas/Error"
        let(:external_id) { "INEXISTENTE" }
        let(:body)        { { plan_id: plan.id } }
        run_test!
      end

      response "422", "Já possui assinatura ativa" do
        schema do
          {
            type:       "object",
            properties: {
              errors: { type: "object", description: "Mapa de campo → lista de erros" }
            }
          }
        end

        let(:external_id) { "EXT123" }
        let(:body)        { { plan_id: plan.id } }
        run_test!
      end
    end
  end
end

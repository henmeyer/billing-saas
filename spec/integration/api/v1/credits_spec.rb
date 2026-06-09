require 'swagger_helper'

RSpec.describe 'API de Créditos', type: :request do
  let(:account)     { create(:account) }
  let(:raw_token)   { "billing_test_token_credits_swagger" }
  let(:customer)    { create(:customer, account: account, external_id: "EXT123") }
  let(:plan)        { create(:plan, account: account) }
  let(:subscription) { create(:subscription, customer: customer, plan: plan) }
  let(:period)      { create(:subscription_period, subscription: subscription) }
  let(:credit_type) { create(:credit_type, account: account, key: 'coins') }
  let(:api_key) do
    create(:api_key, account: account,
           token_digest: Digest::SHA256.hexdigest(raw_token),
           last_four: raw_token.last(4))
  end

  before do
    set_tenant(account)
    api_key; customer; period; credit_type
    create(:credit_snapshot, subscription_period: period,
           credit_type: credit_type, used: 300, limit: 1000)
  end

  after { ActsAsTenant.current_tenant = nil }

  let(:Authorization) { "Bearer #{raw_token}" }

  path '/api/v1/customers/{external_id}/credits' do
    parameter name:        :external_id,
              in:          :path,
              type:        :string,
              required:    true,
              description: 'ID externo do cliente no seu sistema',
              example:     'EXT123'

    get 'Consultar saldo de créditos' do
      tags        'Créditos'
      security    [{ BearerAuth: [] }]
      produces    'application/json'
      description <<~DESC
        Retorna o saldo atual de todos os tipos de crédito do cliente
        no período de cobrança vigente.

        O saldo é atualizado via `POST /credits/report` pelo seu sistema.
      DESC

      response '200', 'Saldo retornado com sucesso' do
        schema '$ref' => '#/components/schemas/CreditsResponse'
        let(:external_id) { 'EXT123' }
        run_test!
      end

      response '401', 'Token inválido ou ausente' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { 'Bearer invalido' }
        let(:external_id)   { 'EXT123' }
        run_test!
      end

      response '404', 'Cliente não encontrado' do
        schema '$ref' => '#/components/schemas/Error'
        let(:external_id) { 'NAOEXISTE' }
        run_test!
      end
    end
  end

  path '/api/v1/customers/{external_id}/credits/report' do
    parameter name:        :external_id,
              in:          :path,
              type:        :string,
              required:    true,
              description: 'ID externo do cliente',
              example:     'EXT123'

    post 'Reportar uso de créditos' do
      tags        'Créditos'
      security    [{ BearerAuth: [] }]
      consumes    'application/json'
      produces    'application/json'
      description <<~DESC
        Atualiza o uso de créditos do cliente no período atual.

        **Importante:** envie o **total acumulado** usado no período,
        não o incremento. Isso torna a operação idempotente — retries
        não causam duplicação.

        **Exemplo:** se o cliente usou 200 coins ontem e mais 100 hoje,
        envie `used: 300`, não `used: 100`.

        Alertas de threshold (80%, 95%, 100%) são disparados automaticamente
        via webhook quando atingidos.
      DESC

      parameter name:     :body,
                in:       :body,
                required: true,
                schema:   { '$ref' => '#/components/schemas/CreditReportRequest' }

      response '200', 'Uso registrado com sucesso' do
        schema '$ref' => '#/components/schemas/CreditReportResponse'
        let(:external_id) { 'EXT123' }
        let(:body) { { credit_type: 'coins', used: 450, limit: 1000 } }
        run_test!
      end

      response '404', 'Tipo de crédito não encontrado' do
        schema '$ref' => '#/components/schemas/Error'
        let(:external_id) { 'EXT123' }
        let(:body) { { credit_type: 'inexistente', used: 100 } }
        run_test!
      end

      response '422', 'Sem assinatura ativa' do
        schema '$ref' => '#/components/schemas/Error'
        let(:external_id) { 'EXT123' }
        let(:body) { { credit_type: 'coins', used: 100 } }
        before { subscription.update!(status: 'cancelled') }
        run_test!
      end
    end
  end
end

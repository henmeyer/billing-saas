require 'swagger_helper'

RSpec.describe 'API de Assinatura', type: :request do
  let(:account)      { create(:account) }
  let(:raw_token)    { "billing_test_token_subs_swagger" }
  let(:customer)     { create(:customer, account: account, external_id: "EXT123") }
  let(:plan)         { create(:plan, account: account, name: "Pro") }
  let(:currency)     { create(:currency, account: account) }
  let(:subscription) { create(:subscription, customer: customer, plan: plan, currency: currency) }
  let(:api_key) do
    create(:api_key, account: account,
           token_digest: Digest::SHA256.hexdigest(raw_token),
           last_four: raw_token.last(4))
  end

  before do
    set_tenant(account)
    api_key
    create(:plan_price, plan: plan, currency: currency, amount_cents: 19700)
    subscription
  end

  after { ActsAsTenant.current_tenant = nil }

  let(:Authorization) { "Bearer #{raw_token}" }

  path '/api/v1/customers/{external_id}/subscription' do
    parameter name: :external_id, in: :path, type: :string,
              required: true, example: 'EXT123'

    get 'Consultar assinatura ativa' do
      tags        'Assinatura'
      security    [{ BearerAuth: [] }]
      produces    'application/json'
      description <<~DESC
        Retorna os dados da assinatura ativa do cliente, incluindo
        plano, status, moeda e data de renovação.

        Use este endpoint para verificar se um cliente tem acesso ativo
        antes de permitir operações no seu sistema.
      DESC

      response '200', 'Assinatura retornada com sucesso' do
        schema '$ref' => '#/components/schemas/SubscriptionResponse'
        let(:external_id) { 'EXT123' }
        run_test!
      end

      response '401', 'Token inválido' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { 'Bearer invalido' }
        let(:external_id)   { 'EXT123' }
        run_test!
      end

      response '404', 'Sem assinatura ativa' do
        schema '$ref' => '#/components/schemas/Error'
        let(:external_id) { 'EXT123' }
        before { subscription.update!(status: 'cancelled') }
        run_test!
      end
    end
  end
end

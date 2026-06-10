require 'swagger_helper'

RSpec.describe 'Portal do Cliente', type: :request do
  let(:account)     { create(:account) }
  let(:integration) { create(:integration, account: account) }
  let(:customer)    { create(:customer, account: account) }

  let(:raw_token) do
    _key, token = IntegrationApiKey.generate!(integration: integration, name: "swagger-test")
    token
  end

  before do
    set_tenant(account)
    customer.set_identity!(integration: integration, external_id: "EXT123")
  end

  after { ActsAsTenant.current_tenant = nil }

  let(:Authorization) { "Bearer #{raw_token}" }

  path '/api/v1/portal/sessions' do
    post 'Gerar magic link do portal' do
      tags        'Portal'
      security    [{ BearerAuth: [] }]
      consumes    'application/json'
      produces    'application/json'
      description <<~DESC
        Gera um link temporário (15 minutos) para o cliente acessar o portal
        de autoatendimento.

        Use a API Key da integração — o portal mostrará apenas a assinatura
        vinculada a esta integração.

        ## Fluxo típico

        1. Cliente clica "Gerenciar assinatura" no seu sistema
        2. Seu backend chama este endpoint com o `external_id` do cliente
        3. Retorna uma URL expirável (15 min)
        4. Redirecione o cliente para essa URL (ou abra em nova aba)
        5. O cliente acessa o portal com sessão via cookie

        ## Configuração do portal

        O administrador configura, por integração, quais funcionalidades
        ficam disponíveis no portal:

        - **allow_plan_change** — trocar de plano (upgrade/downgrade)
        - **allow_buy_products** — comprar pacotes de créditos
        - **allow_adjust_extras** — ajustar créditos extras da assinatura
        - **show_invoice_history** — ver histórico de faturas
        - **allow_cancel** — cancelar assinatura

        Essas opções são configuráveis em:
        **Configurações → Integrações → [sua integração] → Portal do cliente**

        ## Branding

        O portal suporta personalização visual por integração:
        logo e cor primária, configuráveis no painel de administração.
      DESC

      parameter name: :body, in: :body, required: true, schema: {
        type: 'object',
        required: ['external_id'],
        properties: {
          external_id: {
            type:        'string',
            description: 'ID do cliente no seu sistema (conforme cadastrado na integração)',
            example:     'EXT123'
          }
        }
      }

      response '200', 'Magic link gerado com sucesso' do
        schema '$ref' => '#/components/schemas/PortalSessionResponse'
        let(:body) { { external_id: 'EXT123' } }
        let(:external_id) { 'EXT123' }
        run_test!
      end

      response '401', 'Token inválido ou expirado' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { 'Bearer invalido' }
        let(:body) { { external_id: 'EXT123' } }
        run_test!
      end

      response '404', 'Cliente não encontrado nesta integração' do
        schema '$ref' => '#/components/schemas/Error'
        let(:body) { { external_id: 'NONEXISTENT' } }
        run_test!
      end
    end
  end
end

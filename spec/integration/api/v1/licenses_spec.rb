require 'swagger_helper'

RSpec.describe 'API de Licenças', type: :request do
  let(:account)      { create(:account) }
  let(:raw_token)    { "billing_test_token_licenses_swagger" }
  let(:customer)     { create(:customer, account: account, external_id: "EXT123") }
  let(:plan)         { create(:plan, account: account) }
  let(:subscription) { create(:subscription, customer: customer, plan: plan) }
  let(:license_type) { create(:license_type, account: account, key: 'user_licenses') }
  let(:api_key) do
    create(:api_key, account: account,
           token_digest: Digest::SHA256.hexdigest(raw_token),
           last_four: raw_token.last(4))
  end

  before do
    set_tenant(account)
    api_key; subscription
    create(:plan_license, plan: plan, license_type: license_type, quantity: 20)
    customer.metadata['license_usage'] = { 'user_licenses' => 14 }
    customer.save!
  end

  after { ActsAsTenant.current_tenant = nil }

  let(:Authorization) { "Bearer #{raw_token}" }

  path '/api/v1/customers/{external_id}/licenses' do
    parameter name: :external_id, in: :path, type: :string,
              required: true, example: 'EXT123'

    get 'Consultar licenças ativas' do
      tags        'Licenças'
      security    [{ BearerAuth: [] }]
      produces    'application/json'
      description <<~DESC
        Retorna as licenças alocadas e em uso do cliente no plano atual.

        `allocated: null` indica licença ilimitada.
        Use `POST /licenses/report` para atualizar o uso.
      DESC

      response '200', 'Licenças retornadas com sucesso' do
        schema '$ref' => '#/components/schemas/LicensesResponse'
        let(:external_id) { 'EXT123' }
        run_test!
      end

      response '401', 'Token inválido' do
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

  path '/api/v1/customers/{external_id}/licenses/report' do
    parameter name: :external_id, in: :path, type: :string,
              required: true, example: 'EXT123'

    post 'Reportar uso de licenças' do
      tags        'Licenças'
      security    [{ BearerAuth: [] }]
      consumes    'application/json'
      produces    'application/json'
      description <<~DESC
        Atualiza a quantidade de licenças em uso pelo cliente.

        Envie um mapa de `license_type_key → quantidade_em_uso`.
        Pode enviar apenas os tipos que mudaram.
      DESC

      parameter name:     :body,
                in:       :body,
                required: true,
                schema:   { '$ref' => '#/components/schemas/LicenseReportRequest' }

      response '200', 'Uso registrado com sucesso' do
        schema '$ref' => '#/components/schemas/LicenseReportResponse'
        let(:external_id) { 'EXT123' }
        let(:body) { { licenses: { user_licenses: 16 } } }
        run_test!
      end

      response '404', 'Cliente não encontrado' do
        schema '$ref' => '#/components/schemas/Error'
        let(:external_id) { 'NAOEXISTE' }
        let(:body) { { licenses: { user_licenses: 5 } } }
        run_test!
      end
    end
  end
end

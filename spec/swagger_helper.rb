require 'rails_helper'

RSpec.configure do |config|
  config.swagger_root = Rails.root.join('swagger').to_s

  config.swagger_docs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title:       'Billing SaaS API',
        description: <<~DESC,
          API de integração da plataforma de billing.

          ## Autenticação

          Todas as requisições precisam do header:
          ```
          Authorization: Bearer {sua_api_key}
          ```

          As API Keys são geradas no painel em **Configurações → API Keys**.

          ## Idempotência

          O endpoint de `report` é idempotente — envie o **total acumulado**,
          não o incremento. Isso garante que retries não causem duplicação.

          ## Webhooks de saída

          Configure integrações no painel para receber eventos em tempo real.
          Todos os payloads são assinados com `X-Billing-Signature: sha256=...`.
        DESC
        version:     'v1',
        contact: {
          name:  'Suporte',
          email: 'suporte@billing.com'
        }
      },
      servers: [
        {
          url:         '{protocol}://{host}',
          description: 'Servidor configurável',
          variables: {
            protocol: { default: 'https', enum: ['https', 'http'] },
            host:     { default: 'app.billing.com' }
          }
        }
      ],
      components: {
        securitySchemes: {
          BearerAuth: {
            type:         'http',
            scheme:       'bearer',
            bearerFormat: 'API Key',
            description:  'API Key gerada no painel em Configurações → API Keys'
          }
        },
        schemas: {
          Error: {
            type: 'object',
            properties: {
              error: { type: 'string', example: 'Token inválido ou expirado' }
            }
          },
          CurrencyInfo: {
            type: 'object',
            properties: {
              code:   { type: 'string', example: 'BRL' },
              symbol: { type: 'string', example: 'R$' }
            }
          },
          CreditBalance: {
            type: 'object',
            properties: {
              used:          { type: 'integer', example: 300 },
              limit:         { type: 'integer', example: 1000 },
              balance:       { type: 'integer', example: 700 },
              usage_percent: { type: 'number',  example: 30.0 },
              synced_at:     { type: 'string', format: 'date-time',
                               example: '2026-06-01T10:00:00Z' }
            }
          },
          CreditsResponse: {
            type: 'object',
            properties: {
              customer_id: { type: 'string', example: 'EXT123' },
              credits: {
                type: 'object',
                additionalProperties: { '$ref' => '#/components/schemas/CreditBalance' },
                example: {
                  coins:     { used: 300, limit: 1000, balance: 700,
                               usage_percent: 30.0, synced_at: '2026-06-01T10:00:00Z' },
                  ai_tokens: { used: 50000, limit: 200000, balance: 150000,
                               usage_percent: 25.0, synced_at: '2026-06-01T10:00:00Z' }
                }
              }
            }
          },
          CreditReportRequest: {
            type: 'object',
            required: ['credit_type', 'used'],
            properties: {
              credit_type: {
                type:        'string',
                description: 'Chave do tipo de crédito (ex: coins, ai_tokens)',
                example:     'coins'
              },
              used: {
                type:        'integer',
                description: 'Total acumulado usado no período atual (não o incremento)',
                example:     450
              },
              limit: {
                type:        'integer',
                description: 'Limite atual (opcional — usa o do plano se omitido)',
                example:     1000
              }
            }
          },
          CreditReportResponse: {
            type: 'object',
            properties: {
              balance:       { type: 'integer', example: 550 },
              usage_percent: { type: 'number',  example: 45.0 },
              status: {
                type: 'string',
                enum: ['ok', 'depleted'],
                example: 'ok'
              }
            }
          },
          LicenseInfo: {
            type: 'object',
            properties: {
              allocated: {
                type:        'integer',
                nullable:    true,
                description: 'Quantidade alocada no plano. null = ilimitado',
                example:     20
              },
              used:      { type: 'integer', example: 14 },
              available: {
                type:        'integer',
                nullable:    true,
                description: 'Disponível. null = ilimitado',
                example:     6
              },
              unlimited: { type: 'boolean', example: false }
            }
          },
          LicensesResponse: {
            type: 'object',
            properties: {
              customer_id: { type: 'string', example: 'EXT123' },
              licenses: {
                type: 'object',
                additionalProperties: { '$ref' => '#/components/schemas/LicenseInfo' },
                example: {
                  user_licenses:  { allocated: 20, used: 14, available: 6, unlimited: false },
                  inbox_licenses: { allocated: 10, used: 4,  available: 6, unlimited: false }
                }
              }
            }
          },
          LicenseReportRequest: {
            type: 'object',
            required: ['licenses'],
            properties: {
              licenses: {
                type: 'object',
                additionalProperties: { type: 'integer' },
                description: 'Mapa de license_type_key → quantidade em uso',
                example: { user_licenses: 14, inbox_licenses: 4 }
              }
            }
          },
          LicenseReportResponse: {
            type: 'object',
            properties: {
              status:   { type: 'string', example: 'ok' },
              licenses: {
                type: 'object',
                additionalProperties: { type: 'integer' },
                example: { user_licenses: 14, inbox_licenses: 4 }
              }
            }
          },
          SubscriptionPlan: {
            type: 'object',
            properties: {
              id:            { type: 'integer', example: 1 },
              name:          { type: 'string',  example: 'Pro' },
              billing_cycle: { type: 'string',  example: 'monthly' },
              price_cents:   { type: 'integer', example: 19700 },
              currency:      { type: 'string',  example: 'BRL' }
            }
          },
          SubscriptionResponse: {
            type: 'object',
            properties: {
              customer_id: { type: 'string', example: 'EXT123' },
              plan:        { '$ref' => '#/components/schemas/SubscriptionPlan' },
              status: {
                type: 'string',
                enum: ['active', 'past_due', 'cancelled', 'trialing'],
                example: 'active'
              },
              gateway:            { type: 'string', example: 'asaas' },
              current_period_end: {
                type: 'string', format: 'date-time',
                example: '2026-07-01T00:00:00Z'
              },
              started_at: {
                type: 'string', format: 'date-time',
                example: '2026-01-01T00:00:00Z'
              }
            }
          }
        }
      },
      security: [{ BearerAuth: [] }]
    }
  }

  config.swagger_format = :yaml
end

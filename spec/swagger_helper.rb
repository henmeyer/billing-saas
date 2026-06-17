require "rails_helper"

RSpec.configure do |config|
  config.swagger_root = Rails.root.join("swagger").to_s

  config.swagger_docs = {
    "v1/swagger.yaml" => {
      openapi:    "3.0.1",
      info:       {
        title:       "Billing SaaS API",
        description: <<~DESC,
          API de integração da plataforma de billing.

          ## Autenticação

          Use a **API Key da integração**, não a API Key de conta.

          ```
          Authorization: Bearer billing_int_sua_chave
          ```

          As API Keys de integração são geradas em:
          **Configurações → Integrações → [sua integração] → API Keys**

          > ⚠ API Keys de conta (`billing_...`) não funcionam nesta API.
          > Elas servem apenas para autenticar no painel.

          ## Namespace de clientes

          O `external_id` é resolvido dentro do contexto da sua integração.
          O mesmo `external_id: "1"` em duas integrações diferentes
          corresponde a clientes diferentes.

          ## Idempotência

          O endpoint de `report` é idempotente — envie o **total acumulado**,
          não o incremento. Isso garante que retries não causem duplicação.

          ## Webhooks de saída

          Configure integrações no painel para receber eventos em tempo real.
          Todos os payloads são assinados com `X-Billing-Signature: sha256=...`.
        DESC
        version:     "v1",
        contact:     {
          name:  "Suporte",
          email: "suporte@billing.com"
        }
      },
      servers:    [
        {
          url:         "{protocol}://{host}",
          description: "Servidor configurável",
          variables:   {
            protocol: { default: "https", enum: %w[https http] },
            host:     { default: "app.billing.com" }
          }
        }
      ],
      components: {
        securitySchemes: {
          BearerAuth: {
            type:         "http",
            scheme:       "bearer",
            bearerFormat: "API Key",
            description:  "API Key gerada no painel em Configurações → API Keys"
          }
        },
        schemas:         {
          Error:                          {
            type:       "object",
            properties: {
              error: { type: "string", example: "Token inválido ou expirado" }
            }
          },
          CurrencyInfo:                   {
            type:       "object",
            properties: {
              code:   { type: "string", example: "BRL" },
              symbol: { type: "string", example: "R$" }
            }
          },
          CreditBalance:                  {
            type:       "object",
            properties: {
              used:          { type: "integer", example: 300 },
              limit:         { type: "integer", example: 1000 },
              balance:       { type: "integer", example: 700 },
              usage_percent: { type: "number",  example: 30.0 },
              synced_at:     { type: "string", format: "date-time",
                               example: "2026-06-01T10:00:00Z" }
            }
          },
          CreditsResponse:                {
            type:       "object",
            properties: {
              customer_id: { type: "string", example: "EXT123" },
              credits:     {
                type:                 "object",
                additionalProperties: { "$ref" => "#/components/schemas/CreditBalance" },
                example:              {
                  coins:     { used: 300, limit: 1000, balance: 700,
                               usage_percent: 30.0, synced_at: "2026-06-01T10:00:00Z" },
                  ai_tokens: { used: 50_000, limit: 200_000, balance: 150_000,
                               usage_percent: 25.0, synced_at: "2026-06-01T10:00:00Z" }
                }
              }
            }
          },
          CreditReportRequest:            {
            type:       "object",
            required:   %w[credit_type used],
            properties: {
              credit_type: {
                type:        "string",
                description: "Chave do tipo de crédito (ex: coins, ai_tokens)",
                example:     "coins"
              },
              used:        {
                type:        "integer",
                description: "Total acumulado usado no período atual (não o incremento)",
                example:     450
              },
              limit:       {
                type:        "integer",
                description: "Limite atual (opcional — usa o do plano se omitido)",
                example:     1000
              }
            }
          },
          CreditReportResponse:           {
            type:       "object",
            properties: {
              balance:       { type: "integer", example: 550 },
              usage_percent: { type: "number",  example: 45.0 },
              status:        {
                type:    "string",
                enum:    %w[ok depleted],
                example: "ok"
              }
            }
          },
          LicenseInfo:                    {
            type:       "object",
            properties: {
              allocated: {
                type:        "integer",
                nullable:    true,
                description: "Quantidade alocada no plano. null = ilimitado",
                example:     20
              },
              used:      { type: "integer", example: 14 },
              available: {
                type:        "integer",
                nullable:    true,
                description: "Disponível. null = ilimitado",
                example:     6
              },
              unlimited: { type: "boolean", example: false }
            }
          },
          LicensesResponse:               {
            type:       "object",
            properties: {
              customer_id: { type: "string", example: "EXT123" },
              licenses:    {
                type:                 "object",
                additionalProperties: { "$ref" => "#/components/schemas/LicenseInfo" },
                example:              {
                  user_licenses:  { allocated: 20, used: 14, available: 6, unlimited: false },
                  inbox_licenses: { allocated: 10, used: 4,  available: 6, unlimited: false }
                }
              }
            }
          },
          LicenseReportRequest:           {
            type:       "object",
            required:   ["licenses"],
            properties: {
              licenses: {
                type:                 "object",
                additionalProperties: { type: "integer" },
                description:          "Mapa de license_type_key → quantidade em uso",
                example:              { user_licenses: 14, inbox_licenses: 4 }
              }
            }
          },
          LicenseReportResponse:          {
            type:       "object",
            properties: {
              status:   { type: "string", example: "ok" },
              licenses: {
                type:                 "object",
                additionalProperties: { type: "integer" },
                example:              { user_licenses: 14, inbox_licenses: 4 }
              }
            }
          },
          SubscriptionPlan:               {
            type:       "object",
            properties: {
              id:            { type: "integer", example: 1 },
              name:          { type: "string",  example: "Pro" },
              billing_cycle: { type: "string",  example: "monthly" },
              price_cents:   { type: "integer", example: 19_700 },
              currency:      { type: "string",  example: "BRL" }
            }
          },
          SubscriptionResponse:           {
            type:       "object",
            properties: {
              customer_id:        { type: "string", example: "EXT123" },
              plan:               { "$ref" => "#/components/schemas/SubscriptionPlan" },
              status:             {
                type:    "string",
                enum:    %w[active past_due cancelled trialing],
                example: "active"
              },
              gateway:            { type: "string", example: "asaas" },
              current_period_end: {
                type: "string", format: "date-time",
                example: "2026-07-01T00:00:00Z"
              },
              started_at:         {
                type: "string", format: "date-time",
                example: "2026-01-01T00:00:00Z"
              }
            }
          },

          # --- Portal schemas ---
          PortalSessionResponse:          {
            type:       "object",
            properties: {
              url:        {
                type:        "string",
                description: "URL do portal com token embutido. Redirecione o cliente para esta URL.",
                example:     "https://billing.app/portal/abc123def456ghi789..."
              },
              expires_in: {
                type:        "integer",
                description: "Tempo de vida do link em segundos (900 = 15 minutos)",
                example:     900
              },
              expires_at: {
                type:        "string",
                format:      "date-time",
                description: "Data/hora exata de expiração do link (ISO 8601)",
                example:     "2026-06-10T15:30:00Z"
              }
            }
          },

          # --- Webhook schemas ---
          WebhookCustomer:                {
            type:       "object",
            properties: {
              id:          { type: "string", example: "42" },
              external_id: { type: "string", example: "EXT123" },
              name:        { type: "string", example: "Empresa X" },
              email:       { type: "string", example: "admin@empresax.com" }
            }
          },
          WebhookBase:                    {
            type:       "object",
            required:   %w[event uuid timestamp account_id customer],
            properties: {
              event:      {
                type:        "string",
                description: "Tipo do evento",
                example:     "payment.received"
              },
              uuid:       {
                type:        "string",
                format:      "uuid",
                description: "Identificador único do disparo. Use para deduplicação e rastreamento.",
                example:     "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
              },
              timestamp:  {
                type:    "string",
                format:  "date-time",
                example: "2026-06-01T14:30:00Z"
              },
              account_id: {
                type:    "string",
                example: "1"
              },
              test:       {
                type:        "boolean",
                description: "true quando disparado pelo botão de teste. Ignore em produção.",
                example:     false
              },
              customer:   { "$ref" => "#/components/schemas/WebhookCustomer" },
              features:   {
                type:                 "object",
                description:          "Features habilitadas no plano atual do cliente",
                additionalProperties: { type: "boolean" },
                example:              { "ai_enabled" => true, "export_reports" => false }
              },
              data:       {
                type:        "object",
                description: "Dados específicos do evento"
              }
            }
          },
          WebhookSubscriptionActivated:   {
            allOf: [
              { "$ref" => "#/components/schemas/WebhookBase" },
              {
                type:       "object",
                properties: {
                  event: { type: "string", enum: ["subscription.activated"] },
                  data:  {
                    type:       "object",
                    properties: {
                      plan: {
                        type:       "object",
                        properties: {
                          id:   { type: "integer", example: 1 },
                          name: { type: "string",  example: "Pro" }
                        }
                      }
                    }
                  }
                }
              }
            ]
          },
          WebhookSubscriptionCancelled:   {
            allOf: [
              { "$ref" => "#/components/schemas/WebhookBase" },
              {
                type:       "object",
                properties: {
                  event: { type: "string", enum: ["subscription.cancelled"] },
                  data:  { type: "object", example: {} }
                }
              }
            ]
          },
          WebhookSubscriptionPastDue:     {
            allOf: [
              { "$ref" => "#/components/schemas/WebhookBase" },
              {
                type:       "object",
                properties: {
                  event: { type: "string", enum: ["subscription.past_due"] },
                  data:  { type: "object", example: {} }
                }
              }
            ]
          },
          WebhookSubscriptionRenewed:     {
            allOf: [
              { "$ref" => "#/components/schemas/WebhookBase" },
              {
                type:       "object",
                properties: {
                  event: { type: "string", enum: ["subscription.renewed"] },
                  data:  {
                    type:       "object",
                    properties: {
                      period_end: {
                        type:    "string",
                        format:  "date-time",
                        example: "2026-07-01T00:00:00Z"
                      }
                    }
                  }
                }
              }
            ]
          },
          WebhookSubscriptionTrialEnding: {
            allOf: [
              { "$ref" => "#/components/schemas/WebhookBase" },
              {
                type:       "object",
                properties: {
                  event: { type: "string", enum: ["subscription.trial_ending"] },
                  data:  {
                    type:       "object",
                    properties: {
                      trial_ends_at:  { type: "string", format: "date-time",
                                        example: "2026-06-04T00:00:00Z" },
                      days_remaining: { type: "integer", example: 3 }
                    }
                  }
                }
              }
            ]
          },
          WebhookPlanChanged:             {
            allOf: [
              { "$ref" => "#/components/schemas/WebhookBase" },
              {
                type:       "object",
                properties: {
                  event: { type: "string", enum: ["plan.changed"] },
                  data:  {
                    type:       "object",
                    properties: {
                      previous_plan: {
                        type:       "object",
                        properties: {
                          id:   { type: "integer", example: 1 },
                          name: { type: "string",  example: "Starter" }
                        }
                      },
                      new_plan:      {
                        type:       "object",
                        properties: {
                          id:   { type: "integer", example: 2 },
                          name: { type: "string",  example: "Pro" }
                        }
                      }
                    }
                  }
                }
              }
            ]
          },
          WebhookPaymentReceived:         {
            allOf: [
              { "$ref" => "#/components/schemas/WebhookBase" },
              {
                type:       "object",
                properties: {
                  event: { type: "string", enum: ["payment.received"] },
                  data:  {
                    type:       "object",
                    properties: {
                      amount_cents: { type: "integer", example: 19_700 },
                      gateway:      { type: "string",  example: "asaas",
                                      enum: %w[asaas stripe dlocal_go] },
                      charge_id:    { type: "string",  example: "pay_abc123" }
                    }
                  }
                }
              }
            ]
          },
          WebhookPaymentFailed:           {
            allOf: [
              { "$ref" => "#/components/schemas/WebhookBase" },
              {
                type:       "object",
                properties: {
                  event: { type: "string", enum: ["payment.failed"] },
                  data:  {
                    type:       "object",
                    properties: {
                      amount_cents: { type: "integer", example: 19_700 },
                      gateway:      { type: "string",  example: "stripe" },
                      attempt:      { type: "integer", example: 1,
                                      description: "Número da tentativa de cobrança" }
                    }
                  }
                }
              }
            ]
          },
          WebhookCreditsThresholdReached: {
            allOf: [
              { "$ref" => "#/components/schemas/WebhookBase" },
              {
                type:       "object",
                properties: {
                  event: { type: "string", enum: ["credits.threshold_reached"] },
                  data:  {
                    type:       "object",
                    properties: {
                      credit_type:   { type: "string",  example: "coins" },
                      used:          { type: "integer", example: 800 },
                      limit:         { type: "integer", example: 1000 },
                      usage_percent: { type: "number",  example: 80.0 },
                      threshold:     { type: "integer", example: 80,
                                       enum: [80, 95],
                                       description: "Percentual que disparou o alerta" }
                    }
                  }
                }
              }
            ]
          },
          WebhookCreditsDepleted:         {
            allOf: [
              { "$ref" => "#/components/schemas/WebhookBase" },
              {
                type:       "object",
                properties: {
                  event: { type: "string", enum: ["credits.depleted"] },
                  data:  {
                    type:       "object",
                    properties: {
                      credit_type:   { type: "string",  example: "coins" },
                      used:          { type: "integer", example: 1000 },
                      limit:         { type: "integer", example: 1000 },
                      usage_percent: { type: "number",  example: 100.0 }
                    }
                  }
                }
              }
            ]
          },
          WebhookCreditsRecharged:        {
            allOf: [
              { "$ref" => "#/components/schemas/WebhookBase" },
              {
                type:       "object",
                properties: {
                  event: { type: "string", enum: ["credits.recharged"] },
                  data:  {
                    type:       "object",
                    properties: {
                      credit_type: { type: "string",  example: "coins" },
                      added:       { type: "integer", example: 1000,
                                      description: "Créditos adicionados" },
                      new_balance: { type: "integer", example: 2000 }
                    }
                  }
                }
              }
            ]
          },
          WebhookLicenseUpdated:          {
            allOf: [
              { "$ref" => "#/components/schemas/WebhookBase" },
              {
                type:       "object",
                properties: {
                  event: { type: "string", enum: ["license.updated"] },
                  data:  {
                    type:       "object",
                    properties: {
                      license_type:      { type: "string",  example: "user_licenses" },
                      previous_quantity: { type: "integer", example: 10 },
                      new_quantity:      { type: "integer", example: 20 }
                    }
                  }
                }
              }
            ]
          }
        }
      },
      security:   [{ BearerAuth: [] }]
    }
  }

  config.swagger_format = :yaml
end

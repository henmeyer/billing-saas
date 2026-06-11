# Billing SaaS — Contexto permanente para o Claude Code

## O que é esse projeto

Plataforma de billing para empresas de software que vendem planos com
licenças e créditos consumíveis. Multi-gateway (Asaas + Stripe), multi-tenant,
com API de integração para sistemas externos via webhooks.

---

## Stack

| Camada        | Tecnologia                                   |
| ------------- | -------------------------------------------- |
| Backend       | Ruby on Rails 8                              |
| Frontend      | Vue 3 + Inertia.js + Vite-Rails              |
| Banco         | PostgreSQL via Supabase (só o banco)         |
| Jobs          | Sidekiq + Redis                              |
| Gateways      | Asaas + Stripe + dLocal Go (pattern adapter) |
| IA            | Claude Haiku (4 pontos específicos)          |
| Infra         | Hetzner VPS + Kamal                          |
| Auth          | Devise                                       |
| Multi-tenancy | acts_as_tenant                               |
| Storage       | Cloudflare R2 via Active Storage             |

---

## Regras que nunca mudam

### Geral

- Sempre seguir as decisões de arquitetura deste arquivo
- Nunca adicionar gems sem perguntar
- Sempre criar specs junto com cada implementação
- Nunca refatorar algo já implementado sem perguntar
- Para resetar o banco: `rails db:drop db:create db:migrate`

### Rails

- Multi-tenancy com `acts_as_tenant` — NUNCA fazer query sem tenant
- Lógica de negócio em Service Objects (`app/services/`), nunca em controllers
- Controllers: autenticar → autorizar → chamar service → render inertia
- Migrations são permanentes — sempre pensar antes de criar

### Segurança

- Nunca salvar API keys ou secrets em texto puro
- API keys: SHA256 digest, nunca o token raw
- Chaves de gateway: `Rails.application.message_verifier(:gateway_keys)`
- Sempre validar HMAC em webhooks de entrada
- Sempre `ActiveSupport::SecurityUtils.secure_compare` para comparar tokens

### Frontend

- Todas as páginas em Vue via Inertia.js
- `render inertia: 'Page/Name', props: { ... }` em todos os controllers
- `inertia_share` no ApplicationController para auth e flash globais
- Componentes em `app/javascript/components/`
- Páginas em `app/javascript/pages/`

### IA

- Claude Haiku para textos curtos
- Sempre registrar uso de tokens após cada chamada
- Nunca usar IA onde lógica determinística resolve

---

## Decisões de arquitetura

### Multi-tenancy

- Cada empresa = uma `Account`
- `ActsAsTenant.require_tenant = true`
- Controllers de app: tenant via `current_user.account`
- Controllers de API: tenant via API key
- Controllers de Webhook: tenant via API key no header

### Gateways

- Interface comum: `Gateways::Base`
- Adapters: `Gateways::StripeAdapter`, `Gateways::AsaasAdapter`, `Gateways::DlocalGoAdapter`
- Factory: `Gateways::Base.for("stripe")`, `Gateways::Base.for("asaas")`, `Gateways::Base.for("dlocal_go")`
- NUNCA chamar os gateways diretamente fora dos adapters
- Dados específicos por gateway em `gateway_data:jsonb`
- Stripe: precisa de `product_id` + `price_id`
- Asaas: só valor e ciclo

#### dLocal Go — regras:

- Primeiro pagamento: checkout com `allow_recurring: true` (redirect para o cliente)
- `checkout_id` salvo em `customer.gateway_data["dlocal_go"]["checkout_id"]`
- Renovações: `create_recurring_charge` com `checkout_id` (automático, sem redirect)
- Compras avulsas: `create_charge` normal (redirect para checkout)
- `cancel_subscription`: noop (não existe subscription no gateway)
- `update_subscription`: noop (próxima cobrança usa novo valor)
- `Subscriptions::RenewDlocalGoJob` roda diariamente (06:00 UTC) e cobra via recurring
- Assinatura criada com status `pending` até o primeiro pagamento ser confirmado via webhook
- NUNCA usar subscription/plan endpoints nativos do dLocal Go

### Assinaturas

- Uma assinatura por cliente por integração que RENOVA (nunca cria nova)
- `gateway_subscription_id` nunca muda
- Renovação: atualiza período + cria `subscription_period`

### Licenças, créditos e integrações — DECISÃO IMPORTANTE

- `license_types` e `credit_types` são GLOBAIS da `account`
- Cada `integration` configura quais tipos ela usa via `integration_field_configs`
- O `plan` define as quantidades UMA vez em `plan_licenses` e `plan_credits`
- Essas quantidades valem para TODAS as integrações vinculadas ao plano
- Vínculo plano ↔ integrações via `plan_integrations`
- Exemplo:
  - LicenseType `user_licenses` existe uma vez na conta
  - Integração A usa `user_licenses` e `coins`
  - Integração B usa `user_licenses`, `coins` e `ai_tokens`
  - Plano Pro define: `user_licenses=20`, `coins=5000`, `ai_tokens=100k`
  - Integração A recebe 20 user_licenses e 5000 coins
  - Integração B recebe 20 user_licenses, 5000 coins e 100k ai_tokens

### Créditos

- `credit_snapshots` vinculados ao `subscription_period`
- Renovação = novo período = contagem zerada
- Sistema externo é fonte de verdade do USO
- Este sistema é fonte de verdade do LIMITE
- Webhook reporta TOTAL usado (não incremento) — idempotente

### Webhooks

- Entrada: `/webhooks/asaas`, `/webhooks/stripe`, `/webhooks/dlocal_go`, `/webhooks/omnichannel`
- Saída: tabela `integrations`, disparo via Sidekiq
- Payload assinado com HMAC-SHA256
- Retry exponencial: 1min → 5min → 30min → 2h → 8h

---

## Schema do banco

```
accounts                    tenant raiz
users                       account_id, name, email, role

license_types               account_id, key, label, unit
credit_types                account_id, key, label, unit, reset_cycle

integrations                account_id, name, url, secret, events:array, active
integration_field_configs   integration_id, license_type_id?, credit_type_id?, field_type

plans                       account_id, name, price_cents, billing_cycle, gateway_data:jsonb
plan_integrations           plan_id, integration_id
plan_licenses               plan_id, license_type_id, quantity
plan_credits                plan_id, credit_type_id, quantity, rollover
products                    add-ons avulsos

customers                   account_id, name, email, external_id, status, health_score, gateway_data:jsonb
payment_gateways            account_id, provider, api_key_enc, webhook_secret

subscriptions               customer_id, plan_id, gateway, gateway_subscription_id, status, period_*
subscription_plan_changes   histórico de upgrades/downgrades
subscription_periods        subscription_id, period_start, period_end

credit_snapshots            subscription_period_id, credit_type_id, used, limit, balance, usage_percent
credit_alerts               customer_id, credit_type_id, threshold, period_start

charges                     customer_id, subscription_id, gateway, gateway_charge_id, amount_cents, status

webhook_logs                integration_id, customer_id, event, payload:jsonb, status, attempts
api_keys                    account_id, name, token_digest, last_four, active
```

---

## Estrutura de pastas esperada

```
app/
  controllers/
    application_controller.rb
    api/v1/base_controller.rb
    api/v1/credits_controller.rb
    api/v1/licenses_controller.rb
    api/v1/subscriptions_controller.rb
    webhooks/base_controller.rb
    webhooks/asaas_controller.rb
    webhooks/stripe_controller.rb
    webhooks/dlocal_go_controller.rb
    webhooks/omnichannel_controller.rb
    users/registrations_controller.rb
    dashboard_controller.rb
    plans_controller.rb
    customers_controller.rb
    integrations_controller.rb
    api_keys_controller.rb
    payment_gateways_controller.rb

  models/
    account.rb, user.rb
    license_type.rb, credit_type.rb
    integration.rb, integration_field_config.rb
    plan.rb, plan_integration.rb, plan_license.rb, plan_credit.rb
    product.rb, customer.rb, payment_gateway.rb
    subscription.rb, subscription_period.rb, subscription_plan_change.rb
    credit_snapshot.rb, credit_alert.rb, charge.rb
    webhook_log.rb, api_key.rb

  services/
    accounts/create_service.rb
    seeds/default_types_service.rb
    gateways/base.rb, stripe_adapter.rb, asaas_adapter.rb, dlocal_go_adapter.rb
    credits/check_thresholds_service.rb
    dashboard/stats_service.rb
    webhooks/dispatch_service.rb
    ia/churn_alert_service.rb

  jobs/
    webhooks/dispatch_job.rb
    webhooks/process_asaas_event_job.rb
    webhooks/process_stripe_event_job.rb
    webhooks/process_dlocal_go_event_job.rb
    webhooks/sync_credits_job.rb
    subscriptions/renew_dlocal_go_job.rb

javascript/
  components/
    Layout/AppLayout.vue, Sidebar.vue, Topbar.vue, NavLink.vue, FlashMessages.vue
    Shared/StatCard.vue, Badge.vue, ProgressBar.vue, ConfirmButton.vue
  pages/
    Auth/Login.vue, Register.vue
    Dashboard/Index.vue
    Plans/Index.vue, Form.vue
    Customers/Index.vue, Show.vue, Form.vue
    Integrations/Index.vue, Form.vue
    ApiKeys/Index.vue
```

---

## API de integração

```
Authorization: Bearer {api_key}

GET  /api/v1/customers/:external_id/credits
POST /api/v1/customers/:external_id/credits/report
GET  /api/v1/customers/:external_id/licenses
POST /api/v1/customers/:external_id/licenses/report
GET  /api/v1/customers/:external_id/subscription
```

---

## Eventos de webhook de saída

```
subscription.activated    subscription.cancelled    subscription.past_due
subscription.renewed      subscription.trial_ending plan.changed
payment.received          payment.failed
credits.threshold_reached credits.depleted          credits.recharged
license.updated
```

---

## Roadmap

### Fase 1 — Fundação (PHASE1.md) ← começar aqui

### Fase 2 — Integrações (PHASE2.md)

### Frontend (PHASE_FRONTEND.md)

### Fase 3 — IA (pendente)

---

## Comandos úteis

```bash
rails db:drop db:create db:migrate   # resetar banco
rails server
bin/vite dev
bundle exec sidekiq
bundle exec rspec
kamal deploy
```

---

## Variáveis de ambiente

```
DATABASE_URL, REDIS_URL, RAILS_MASTER_KEY
ANTHROPIC_API_KEY
STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET
ASAAS_API_KEY, ASAAS_WEBHOOK_SECRET
DLOCAL_GO_API_KEY, DLOCAL_GO_SECRET_KEY, DLOCAL_GO_ENV
OMNICHANNEL_WEBHOOK_SECRET
```

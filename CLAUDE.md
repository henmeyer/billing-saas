# Billing SaaS — Contexto permanente para o Claude Code

## O que é esse projeto

Plataforma de billing para empresas de software que vendem planos com
licenças e créditos consumíveis. Qualquer SaaS que cobra mensalidade +
licenças por recurso + créditos consumíveis pode usar.

O gestor centraliza receita de múltiplos gateways (Asaas, Stripe), gerencia
planos e licenças em um lugar só, e integra com o próprio software via
webhooks e API REST.

---

## Stack

| Camada        | Tecnologia                                                                   |
| ------------- | ---------------------------------------------------------------------------- |
| Backend       | Ruby on Rails 8                                                              |
| Frontend      | Vue 3 + Vite-Rails (componentes em ilhas, não SPA separada)                  |
| Banco         | PostgreSQL via Supabase (só o banco — sem Edge Functions, sem Auth Supabase) |
| Jobs          | Sidekiq + Redis                                                              |
| Gateways      | Asaas + Stripe (pattern adapter)                                             |
| IA            | Claude Haiku (insights moderados, 4 pontos específicos)                      |
| Infra         | Hetzner VPS + Kamal                                                          |
| Auth          | Devise                                                                       |
| Multi-tenancy | acts_as_tenant                                                               |
| Storage       | Cloudflare R2 via Active Storage                                             |

---

## Regras que nunca mudam

### Geral

- Sempre seguir as decisões de arquitetura deste arquivo
- Nunca adicionar gems fora das já definidas sem perguntar
- Nunca criar features fora do escopo sem perguntar
- Sempre criar specs junto com cada implementação
- Sempre perguntar antes de refatorar algo já implementado

### Rails

- Multi-tenancy com `acts_as_tenant` — NUNCA fazer query sem tenant
- Lógica de negócio em Service Objects (`app/services/`), nunca em controllers
- Controllers só fazem: autenticar, autorizar, chamar service, renderizar
- Usar `ApplicationRecord` em todos os models
- Migrations são irreversíveis em produção — sempre pensar antes de criar

### Segurança

- Nunca salvar API keys, senhas ou secrets em texto puro no banco
- API keys: salvar só o SHA256 digest, nunca o token raw
- Chaves de gateway: criptografar com `Rails.application.message_verifier`
- Sempre validar assinatura HMAC em webhooks de entrada
- Sempre usar `ActiveSupport::SecurityUtils.secure_compare` para comparar tokens

### Frontend

- Vue só onde há interatividade real (dashboard, gráficos, formulários complexos)
- ERB para páginas simples (listagens, configurações)
- Nunca criar SPA separada — tudo dentro do Rails via vite-rails

### IA

- Usar Claude Haiku para textos curtos (alertas, resumos curtos)
- Usar Claude Sonnet só se precisar de raciocínio mais complexo
- Sempre registrar uso de tokens em `uso_tokens` após cada chamada
- Nunca usar IA onde lógica determinística resolve

---

## Decisões de arquitetura

### Multi-tenancy

- Cada empresa = uma `Account`
- `ActsAsTenant.require_tenant = true`
- Controllers de app: tenant via `current_user.account`
- Controllers de API (`/api/v1/`): tenant via API key
- Controllers de Webhook: tenant via gateway ou account_id no payload
- Nunca usar `.where(account_id: x)` manual — acts_as_tenant cuida disso

### Autenticação

- Usuários internos: Devise
- API externa: API Keys com SHA256 (não bcrypt — lookup frequente)
- Token mostrado UMA vez na criação, nunca mais
- Header: `Authorization: Bearer {token}`
- Roles: `owner`, `admin`, `member`

### Gateways de pagamento

- Interface comum: `Gateways::Base`
- Adapters: `Gateways::StripeAdapter`, `Gateways::AsaasAdapter`
- Factory: `Gateways::Base.for("stripe")` ou `Gateways::Base.for("asaas")`
- NUNCA chamar Stripe ou Asaas diretamente fora dos adapters
- Dados específicos por gateway em `gateway_data:jsonb`:
  ```json
  {
    "stripe": { "product_id": "prod_x", "price_id": "price_y" },
    "asaas": { "billing_type": "BOLETO" }
  }
  ```
- Stripe precisa de `product_id` + `price_id`. Asaas não precisa — só valor e ciclo
- Campo `gateway` (string) em `subscriptions` e `charges` identifica a origem

### Assinaturas

- Uma assinatura por cliente que vai RENOVANDO (nunca cria nova a cada ciclo)
- `gateway_subscription_id` nunca muda (compatível com Asaas e Stripe)
- A cada renovação: atualiza `current_period_start/end` + cria novo `subscription_period`
- Histórico de cobranças em `charges` (múltiplos registros por assinatura)
- Histórico de mudanças de plano em `subscription_plan_changes`

### Créditos e licenças

- `license_types` e `credit_types` são configuráveis por conta (chave livre)
- Licenças: não resetam por padrão (você tem 5 usuários o mês todo)
- Créditos: têm `reset_cycle` configurável (`billing_cycle`, `monthly`, `yearly`, `never`)
- `credit_snapshots` vinculados ao `subscription_period`, NÃO ao customer
  - Razão: o sistema externo contabiliza uso por assinatura ativa
  - Renovação = novo período = contagem zerada naturalmente
- O sistema externo é fonte de verdade do USO
- Este sistema é fonte de verdade do LIMITE
- Sincronização via webhook: externo reporta TOTAL usado (não incremento)
  - Razão: idempotente — retry não duplica débito

### Webhooks

- **Entrada:** rotas dedicadas por gateway (`/webhooks/asaas`, `/webhooks/stripe`, `/webhooks/omnichannel`)
- **Saída:** tabela `integrations` com URL configurável. Disparo via Sidekiq
- Payload de saída sempre assinado com HMAC-SHA256 (`X-Billing-Signature: sha256=...`)
- Retry com backoff exponencial: 1min → 5min → 30min → 2h → 8h (5 tentativas)
- Idempotência: `gateway_charge_id` único em `charges` evita duplicatas
- Responder `200 OK` imediatamente e processar em background (Sidekiq)

### IA (moderada — só 4 pontos)

1. **Health score** — lógica determinística, SEM IA
2. **Alerta de churn** — Claude gera narrativa em linguagem natural
3. **Resumo mensal** — gerado dia 1 de cada mês, enviado por email
4. **Previsão de receita** — modelo simples + narrativa IA

---

## Schema do banco

```
accounts                  -- tenant raiz
users                     -- account_id, name, email, role

license_types             -- account_id, key, label, unit
credit_types              -- account_id, key, label, unit, reset_cycle

plans                     -- account_id, name, price_cents, billing_cycle, gateway_data:jsonb
plan_licenses             -- plan_id, license_type_id, quantity
plan_credits              -- plan_id, credit_type_id, quantity, rollover
products                  -- add-ons avulsos (one_time | recurring | credit_pack)

customers                 -- account_id, name, email, external_id, status, health_score, gateway_data:jsonb
payment_gateways          -- account_id, provider, api_key_enc, webhook_secret

subscriptions             -- customer_id, plan_id, gateway, gateway_subscription_id, status, period_*
subscription_plan_changes -- histórico de upgrades/downgrades
subscription_periods      -- subscription_id, period_start, period_end

credit_snapshots          -- subscription_period_id, credit_type_id, used, limit, balance, usage_percent
credit_alerts             -- customer_id, credit_type_id, threshold, period_start

charges                   -- customer_id, subscription_id, gateway, gateway_charge_id, amount_cents, status

integrations              -- account_id, name, url, secret, events:array, active
webhook_logs              -- integration_id, customer_id, event, payload:jsonb, status, attempts

api_keys                  -- account_id, name, token_digest (SHA256), last_four, active
```

---

## Estrutura de pastas esperada

```
app/
  controllers/
    application_controller.rb
    api/
      v1/
        base_controller.rb
        credits_controller.rb
        licenses_controller.rb
        subscriptions_controller.rb
    webhooks/
      base_controller.rb
      asaas_controller.rb
      stripe_controller.rb
      omnichannel_controller.rb
    users/
      registrations_controller.rb
    api_keys_controller.rb
    plans_controller.rb
    customers_controller.rb
    integrations_controller.rb
    dashboard_controller.rb

  models/
    account.rb, user.rb
    license_type.rb, credit_type.rb
    plan.rb, plan_license.rb, plan_credit.rb, product.rb
    customer.rb, payment_gateway.rb
    subscription.rb, subscription_period.rb, subscription_plan_change.rb
    credit_snapshot.rb, credit_alert.rb
    charge.rb
    integration.rb, webhook_log.rb
    api_key.rb

  services/
    accounts/
      create_service.rb
    seeds/
      default_types_service.rb
    gateways/
      base.rb
      stripe_adapter.rb
      asaas_adapter.rb
    credits/
      check_thresholds_service.rb
      fetch_balance_service.rb
    webhooks/
      dispatch_service.rb
    ia/
      churn_alert_service.rb
      monthly_summary_service.rb

  jobs/
    webhooks/
      dispatch_job.rb
      process_asaas_event_job.rb
      process_stripe_event_job.rb
      process_renewal_job.rb
      sync_credits_job.rb
    ia/
      monthly_summary_job.rb

javascript/
  components/
    Dashboard/
      MrrChart.vue
      CreditUsageBar.vue
      HealthScoreBadge.vue
```

---

## API de integração

```
# Header obrigatório:
Authorization: Bearer {api_key}

GET  /api/v1/customers/:external_id/credits           consultar saldo
POST /api/v1/customers/:external_id/credits/report    reportar uso (total, não incremento)
GET  /api/v1/customers/:external_id/licenses          consultar licenças
POST /api/v1/customers/:external_id/licenses/report   reportar licenças em uso
GET  /api/v1/customers/:external_id/subscription      consultar plano ativo
```

---

## Catálogo de eventos (webhooks de saída)

```
subscription.activated    subscription.cancelled    subscription.past_due
subscription.renewed      subscription.trial_ending plan.changed
payment.received          payment.failed
credits.threshold_reached credits.depleted          credits.recharged
license.updated
```

---

## Roadmap

### Fase 1 — Fundação

- Projeto Rails + Gemfile + banco + Sidekiq + Vite/Vue
- Multi-tenancy (acts_as_tenant)
- Auth (Devise + roles)
- Todas as migrations
- Todos os models
- Service: criar conta + seed de tipos padrão
- Gateway adapters (Base, Stripe, Asaas)
- API Keys (geração + autenticação)
- Rack::Attack

### Fase 2 — Integrações

- Webhook receivers (Asaas, Stripe, Omnichannel)
- Webhook sender com retry (Sidekiq)
- Endpoints da API de integração
- Dashboard básico (MRR, clientes, inadimplência, créditos)
- Views CRUD (planos, clientes, integrações, API keys)

### Fase 3 — Inteligência

- Health score (lógica determinística)
- Alertas de churn com narrativa IA
- Resumo mensal automático por email
- Gráfico de previsão de receita

### Fora do MVP

- Produtos avulsos / add-ons (schema pronto, UI depois)
- Portal do cliente final
- Terceiro gateway
- Rollover de créditos (coluna no schema, lógica depois)

---

## Comandos úteis

```bash
# Desenvolvimento
rails server
bundle exec sidekiq
bin/vite dev

# Banco
rails db:migrate
rails db:rollback

# Testes
bundle exec rspec
bundle exec rspec spec/models/
bundle exec rspec spec/services/

# Deploy
kamal deploy
kamal logs
```

---

## Variáveis de ambiente necessárias

```
DATABASE_URL
REDIS_URL
RAILS_MASTER_KEY
ANTHROPIC_API_KEY
STRIPE_SECRET_KEY
STRIPE_WEBHOOK_SECRET
ASAAS_API_KEY
ASAAS_WEBHOOK_SECRET
OMNICHANNEL_WEBHOOK_SECRET
```

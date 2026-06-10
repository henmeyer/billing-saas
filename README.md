# Billing SaaS

Plataforma de billing multi-tenant para empresas de software que vendem planos com licenças e créditos consumíveis. Suporte a múltiplos gateways de pagamento (Asaas, Stripe, dLocal Go), API de integração para sistemas externos e webhooks bidirecionais.

## Stack

| Camada         | Tecnologia                |
| -------------- | ------------------------- |
| Backend        | Ruby on Rails 8           |
| Frontend       | Vue 3 + Inertia.js + Vite |
| Banco de dados | PostgreSQL (Supabase)     |
| Jobs           | Sidekiq + Redis           |
| Gateways       | Asaas, Stripe, dLocal Go  |
| Auth           | Devise                    |
| Multi-tenancy  | acts_as_tenant            |

## Pré-requisitos

- Ruby 3.3+
- Node.js 20+
- PostgreSQL 15+
- Redis 7+

## Setup

```bash
# Instalar dependências
bundle install
yarn install

# Configurar variáveis de ambiente
cp .env.example .env
# Editar .env com suas credenciais

# Criar e migrar o banco
rails db:create db:migrate

# Iniciar todos os serviços (Rails + Vite + Sidekiq)
bin/dev
```

## Serviços individuais

```bash
rails server          # Backend
bin/vite dev          # Frontend (Vite dev server)
bundle exec sidekiq   # Background jobs
```

## Testes

```bash
bundle exec rspec
```

## Variáveis de ambiente

| Variável                | Descrição                                   |
| ----------------------- | ------------------------------------------- |
| `DATABASE_URL`          | URL de conexão com PostgreSQL               |
| `REDIS_URL`             | URL de conexão com Redis                    |
| `RAILS_MASTER_KEY`      | Chave mestra do Rails                       |
| `STRIPE_SECRET_KEY`     | Chave secreta do Stripe                     |
| `STRIPE_WEBHOOK_SECRET` | Secret para validação de webhooks do Stripe |
| `ASAAS_API_KEY`         | Chave da API do Asaas                       |
| `ASAAS_WEBHOOK_SECRET`  | Secret para validação de webhooks do Asaas  |
| `ANTHROPIC_API_KEY`     | Chave da API da Anthropic (Claude Haiku)    |

## API de integração

Autenticação via Bearer token:

```
Authorization: Bearer {api_key}
```

### Endpoints

```
GET  /api/v1/customers/:external_id/credits
POST /api/v1/customers/:external_id/credits/report
GET  /api/v1/customers/:external_id/licenses
POST /api/v1/customers/:external_id/licenses/report
GET  /api/v1/customers/:external_id/subscription
```

## Webhooks de saída

Eventos disparados para integrações configuradas, com payload assinado via HMAC-SHA256 e retry exponencial automático.

| Evento                      | Descrição                             |
| --------------------------- | ------------------------------------- |
| `subscription.activated`    | Assinatura ativada                    |
| `subscription.renewed`      | Assinatura renovada                   |
| `subscription.cancelled`    | Assinatura cancelada                  |
| `subscription.past_due`     | Assinatura em atraso                  |
| `plan.changed`              | Upgrade/downgrade de plano            |
| `payment.received`          | Pagamento confirmado                  |
| `payment.failed`            | Falha no pagamento                    |
| `credits.threshold_reached` | Créditos atingiram limite configurado |
| `credits.depleted`          | Créditos esgotados                    |
| `credits.recharged`         | Créditos recarregados                 |
| `license.updated`           | Licença atualizada                    |

## Arquitetura

- **Multi-tenancy**: cada empresa é uma `Account`, isolamento via `acts_as_tenant`
- **Gateways**: padrão adapter com factory (`Gateways::Base.for("stripe")`)
- **Lógica de negócio**: concentrada em Service Objects (`app/services/`)
- **Créditos**: sistema externo é fonte de verdade do uso, este sistema é fonte de verdade do limite
- **Assinaturas**: renovação (nunca cria nova), com histórico de períodos

## Licença

Proprietário — todos os direitos reservados.

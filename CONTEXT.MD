# Billing SaaS — Fase 1: Fundação completa

## Objetivo

Implementar a fundação completa do projeto. Siga EXATAMENTE esta ordem —
cada etapa depende da anterior. Não pule etapas, não adicione gems além das
listadas, não crie features fora do escopo definido.

---

## 1. Criar o projeto

```bash
rails new billing --database=postgresql --skip-hotwire --skip-jbuilder
cd billing
```

---

## 2. Gemfile completo

Substitua o Gemfile pelo conteúdo abaixo:

```ruby
source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.3.0"

gem "rails", "~> 8.0"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "bootsnap", require: false

# Multi-tenancy
gem "acts_as_tenant"

# Auth
gem "devise"
gem "bcrypt", "~> 3.1.7"

# Frontend
gem "vite_rails"

# Jobs
gem "sidekiq"
gem "redis", ">= 4.0.1"

# HTTP client (para Asaas)
gem "httparty"

# Gateways
gem "stripe"

# IA
gem "anthropic"

# Segurança
gem "rack-attack"

group :development, :test do
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "debug", platforms: %i[mri windows]
end

group :development do
  gem "web-console"
end
```

```bash
bundle install
```

---

## 3. Configurar banco (config/database.yml)

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  url: <%= ENV["DATABASE_URL"] %>

development:
  <<: *default
  database: billing_development

test:
  <<: *default
  database: billing_test

production:
  <<: *default
  url: <%= ENV["DATABASE_URL"] %>
```

---

## 4. Variáveis de ambiente (.env)

Crie o arquivo `.env` na raiz (adicione ao .gitignore):

```
DATABASE_URL=postgresql://postgres:senha@localhost:5432/billing_development
REDIS_URL=redis://localhost:6379/0
RAILS_MASTER_KEY=
ANTHROPIC_API_KEY=
STRIPE_SECRET_KEY=
STRIPE_WEBHOOK_SECRET=
ASAAS_API_KEY=
ASAAS_WEBHOOK_SECRET=
OMNICHANNEL_WEBHOOK_SECRET=
```

---

## 5. Configurar Sidekiq

**config/application.rb** — adicionar dentro da classe Application:

```ruby
config.active_job.queue_adapter = :sidekiq
```

**config/initializers/sidekiq.rb** — criar arquivo:

```ruby
Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end
```

**config/sidekiq.yml** — criar arquivo:

```yaml
:concurrency: 5
:queues:
  - [critical, 3]
  - [webhooks, 2]
  - [default, 1]
  - [low, 1]
```

---

## 6. Instalar Vite-Rails com Vue

```bash
bundle exec vite install
npm install vue @vitejs/plugin-vue
```

**vite.config.ts** — atualizar:

```typescript
import { defineConfig } from "vite";
import RubyPlugin from "vite-plugin-ruby";
import vue from "@vitejs/plugin-vue";

export default defineConfig({
  plugins: [RubyPlugin(), vue()],
});
```

---

## 7. Rotas (config/routes.rb)

```ruby
require "sidekiq/web"

Rails.application.routes.draw do
  # Auth
  devise_for :users, controllers: {
    registrations: "users/registrations"
  }

  # Sidekiq dashboard (proteger em produção)
  authenticate :user, ->(u) { u.admin? } do
    mount Sidekiq::Web => "/sidekiq"
  end

  # App principal
  root "dashboard#index"

  resources :plans do
    resources :plan_licenses, shallow: true
    resources :plan_credits,  shallow: true
  end

  resources :license_types
  resources :credit_types
  resources :customers do
    resources :subscriptions, shallow: true
  end
  resources :integrations
  resources :api_keys, only: [:index, :create, :destroy]
  resources :payment_gateways

  # Webhooks de entrada (sem auth de usuário)
  namespace :webhooks do
    post "/asaas",        to: "asaas#receive"
    post "/stripe",       to: "stripe#receive"
    post "/omnichannel",  to: "omnichannel#receive"
  end

  # API externa (auth por API key)
  namespace :api do
    namespace :v1 do
      get  "/customers/:external_id/credits",          to: "credits#show"
      post "/customers/:external_id/credits/report",   to: "credits#report"
      get  "/customers/:external_id/licenses",         to: "licenses#show"
      post "/customers/:external_id/licenses/report",  to: "licenses#report"
      get  "/customers/:external_id/subscription",     to: "subscriptions#show"
    end
  end
end
```

---

## 8. Migrations — criar TODAS de uma vez

Execute cada comando e edite a migration gerada com o conteúdo abaixo:

```bash
rails g migration CreateAccounts
rails g migration CreateLicenseTypes
rails g migration CreateCreditTypes
rails g migration CreatePlans
rails g migration CreatePlanLicenses
rails g migration CreatePlanCredits
rails g migration CreateProducts
rails g migration CreateCustomers
rails g migration CreatePaymentGateways
rails g migration CreateSubscriptions
rails g migration CreateSubscriptionPlanChanges
rails g migration CreateSubscriptionPeriods
rails g migration CreateCreditSnapshots
rails g migration CreateCreditAlerts
rails g migration CreateCharges
rails g migration CreateIntegrations
rails g migration CreateWebhookLogs
rails g migration CreateApiKeys
```

### Conteúdo de cada migration:

**CreateAccounts:**

```ruby
class CreateAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :accounts do |t|
      t.string  :name,     null: false
      t.string  :slug,     null: false
      t.string  :status,   null: false, default: "active"
      t.jsonb   :settings, null: false, default: {}
      t.timestamps
    end
    add_index :accounts, :slug, unique: true
  end
end
```

**DeviseCreateUsers** (gerado pelo Devise — ver passo 9):

```ruby
# Será gerado pelo: rails generate devise User
# Adicionar após gerar:
add_column :users, :account_id, :bigint, null: false
add_column :users, :name,       :string, null: false, default: ""
add_column :users, :role,       :string, null: false, default: "member"
add_foreign_key :users, :accounts
add_index :users, :account_id
```

**CreateLicenseTypes:**

```ruby
class CreateLicenseTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :license_types do |t|
      t.references :account, null: false, foreign_key: true
      t.string :key,         null: false
      t.string :label,       null: false
      t.string :unit,        null: false
      t.text   :description
      t.timestamps
    end
    add_index :license_types, [:account_id, :key], unique: true
  end
end
```

**CreateCreditTypes:**

```ruby
class CreateCreditTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :credit_types do |t|
      t.references :account, null: false, foreign_key: true
      t.string :key,          null: false
      t.string :label,        null: false
      t.string :unit,         null: false
      t.string :reset_cycle,  null: false, default: "billing_cycle"
      t.text   :description
      t.timestamps
    end
    add_index :credit_types, [:account_id, :key], unique: true
  end
end
```

**CreatePlans:**

```ruby
class CreatePlans < ActiveRecord::Migration[8.0]
  def change
    create_table :plans do |t|
      t.references :account,    null: false, foreign_key: true
      t.string  :name,          null: false
      t.text    :description
      t.integer :price_cents,   null: false, default: 0
      t.string  :currency,      null: false, default: "BRL"
      t.string  :billing_cycle, null: false, default: "monthly"
      t.integer :trial_days,    null: false, default: 0
      t.boolean :active,        null: false, default: true
      t.datetime :archived_at
      t.jsonb   :gateway_data,  null: false, default: {}
      t.jsonb   :metadata,      null: false, default: {}
      t.timestamps
    end
  end
end
```

**CreatePlanLicenses:**

```ruby
class CreatePlanLicenses < ActiveRecord::Migration[8.0]
  def change
    create_table :plan_licenses do |t|
      t.references :plan,         null: false, foreign_key: true
      t.references :license_type, null: false, foreign_key: true
      t.integer :quantity,        null: false, default: 0
      t.timestamps
    end
    add_index :plan_licenses, [:plan_id, :license_type_id], unique: true
  end
end
```

**CreatePlanCredits:**

```ruby
class CreatePlanCredits < ActiveRecord::Migration[8.0]
  def change
    create_table :plan_credits do |t|
      t.references :plan,        null: false, foreign_key: true
      t.references :credit_type, null: false, foreign_key: true
      t.integer :quantity,       null: false, default: 0
      t.boolean :rollover,       null: false, default: false
      t.timestamps
    end
    add_index :plan_credits, [:plan_id, :credit_type_id], unique: true
  end
end
```

**CreateProducts:**

```ruby
class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.references :account,       null: false, foreign_key: true
      t.string  :name,             null: false
      t.text    :description
      t.integer :price_cents,      null: false, default: 0
      t.string  :currency,         null: false, default: "BRL"
      t.string  :product_type,     null: false, default: "one_time"
      t.references :credit_type,   foreign_key: true
      t.integer :credit_quantity,  default: 0
      t.boolean :active,           null: false, default: true
      t.timestamps
    end
  end
end
```

**CreateCustomers:**

```ruby
class CreateCustomers < ActiveRecord::Migration[8.0]
  def change
    create_table :customers do |t|
      t.references :account,     null: false, foreign_key: true
      t.string  :name,           null: false
      t.string  :email,          null: false
      t.string  :document
      t.string  :phone
      t.string  :external_id
      t.string  :status,         null: false, default: "active"
      t.integer :health_score,   null: false, default: 100
      t.jsonb   :gateway_data,   null: false, default: {}
      t.jsonb   :metadata,       null: false, default: {}
      t.text    :notes
      t.timestamps
    end
    add_index :customers, [:account_id, :email], unique: true
    add_index :customers, [:account_id, :external_id],
              unique: true,
              where: "external_id IS NOT NULL"
  end
end
```

**CreatePaymentGateways:**

```ruby
class CreatePaymentGateways < ActiveRecord::Migration[8.0]
  def change
    create_table :payment_gateways do |t|
      t.references :account,    null: false, foreign_key: true
      t.string  :provider,      null: false
      t.string  :api_key_enc,   null: false
      t.string  :webhook_secret
      t.boolean :active,        null: false, default: true
      t.boolean :default,       null: false, default: false
      t.timestamps
    end
    add_index :payment_gateways, [:account_id, :provider], unique: true
  end
end
```

**CreateSubscriptions:**

```ruby
class CreateSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :subscriptions do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :plan,     null: false, foreign_key: true
      t.string  :status,      null: false, default: "active"
      t.string  :gateway,     null: false
      t.string  :gateway_subscription_id
      t.datetime :started_at,            null: false
      t.datetime :trial_ends_at
      t.datetime :cancelled_at
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.timestamps
    end
    add_index :subscriptions, [:gateway, :gateway_subscription_id],
              unique: true,
              where: "gateway_subscription_id IS NOT NULL"
  end
end
```

**CreateSubscriptionPlanChanges:**

```ruby
class CreateSubscriptionPlanChanges < ActiveRecord::Migration[8.0]
  def change
    create_table :subscription_plan_changes do |t|
      t.references :subscription, null: false, foreign_key: true
      t.references :from_plan,    null: false, foreign_key: { to_table: :plans }
      t.references :to_plan,      null: false, foreign_key: { to_table: :plans }
      t.string  :reason
      t.integer :changed_by_id
      t.timestamps
    end
  end
end
```

**CreateSubscriptionPeriods:**

```ruby
class CreateSubscriptionPeriods < ActiveRecord::Migration[8.0]
  def change
    create_table :subscription_periods do |t|
      t.references :subscription, null: false, foreign_key: true
      t.datetime :period_start,   null: false
      t.datetime :period_end,     null: false
      t.timestamps
    end
    add_index :subscription_periods, [:subscription_id, :period_start],
              unique: true
  end
end
```

**CreateCreditSnapshots:**

```ruby
class CreateCreditSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :credit_snapshots do |t|
      t.references :subscription_period, null: false, foreign_key: true
      t.references :credit_type,         null: false, foreign_key: true
      t.integer :used,          null: false, default: 0
      t.integer :limit,         null: false, default: 0
      t.integer :balance,       null: false, default: 0
      t.float   :usage_percent, null: false, default: 0.0
      t.datetime :synced_at,    null: false
      t.timestamps
    end
    add_index :credit_snapshots,
              [:subscription_period_id, :credit_type_id],
              unique: true,
              name: "index_credit_snapshots_on_period_and_type"
  end
end
```

**CreateCreditAlerts:**

```ruby
class CreateCreditAlerts < ActiveRecord::Migration[8.0]
  def change
    create_table :credit_alerts do |t|
      t.references :customer,    null: false, foreign_key: true
      t.references :credit_type, null: false, foreign_key: true
      t.integer  :threshold,     null: false
      t.datetime :period_start,  null: false
      t.timestamps
    end
  end
end
```

**CreateCharges:**

```ruby
class CreateCharges < ActiveRecord::Migration[8.0]
  def change
    create_table :charges do |t|
      t.references :customer,     null: false, foreign_key: true
      t.references :subscription, null: false, foreign_key: true
      t.string  :gateway,         null: false
      t.string  :gateway_charge_id
      t.integer :amount_cents,    null: false
      t.string  :currency,        null: false, default: "BRL"
      t.string  :status,          null: false, default: "pending"
      t.date    :due_date
      t.datetime :paid_at
      t.timestamps
    end
    add_index :charges, [:gateway, :gateway_charge_id],
              unique: true,
              where: "gateway_charge_id IS NOT NULL"
  end
end
```

**CreateIntegrations:**

```ruby
class CreateIntegrations < ActiveRecord::Migration[8.0]
  def change
    create_table :integrations do |t|
      t.references :account,  null: false, foreign_key: true
      t.string  :name,        null: false
      t.string  :url,         null: false
      t.string  :secret,      null: false
      t.string  :events,      array: true, default: []
      t.boolean :active,      null: false, default: true
      t.integer :retry_count, null: false, default: 5
      t.datetime :last_error_at
      t.timestamps
    end
  end
end
```

**CreateWebhookLogs:**

```ruby
class CreateWebhookLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :webhook_logs do |t|
      t.references :integration, null: false, foreign_key: true
      t.references :customer,    null: false, foreign_key: true
      t.string  :event,          null: false
      t.jsonb   :payload,        null: false, default: {}
      t.string  :status,         null: false, default: "pending"
      t.integer :attempts,       null: false, default: 0
      t.datetime :next_retry_at
      t.timestamps
    end
    add_index :webhook_logs, [:integration_id, :status]
    add_index :webhook_logs, :next_retry_at
  end
end
```

**CreateApiKeys:**

```ruby
class CreateApiKeys < ActiveRecord::Migration[8.0]
  def change
    create_table :api_keys do |t|
      t.references :account,   null: false, foreign_key: true
      t.string  :name,         null: false
      t.string  :token_digest, null: false
      t.string  :last_four,    null: false
      t.datetime :last_used_at
      t.datetime :expires_at
      t.boolean :active,       null: false, default: true
      t.timestamps
    end
    add_index :api_keys, :token_digest, unique: true
  end
end
```

---

## 9. Instalar Devise e gerar User

```bash
rails generate devise:install
rails generate devise User
```

Editar a migration gerada pelo Devise para adicionar os campos extras:

```ruby
# Adicionar dentro do create_table :users, antes de t.timestamps:
t.references :account, null: false, foreign_key: true
t.string :name,  null: false, default: ""
t.string :role,  null: false, default: "member"
```

```bash
rails db:create
rails db:migrate
```

---

## 10. Models

### app/models/account.rb

```ruby
class Account < ApplicationRecord
  has_many :users
  has_many :plans
  has_many :customers
  has_many :license_types
  has_many :credit_types
  has_many :integrations
  has_many :api_keys
  has_many :payment_gateways

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, on: :create

  private

  def generate_slug
    self.slug ||= name.parameterize
  end
end
```

### app/models/user.rb

```ruby
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  belongs_to :account

  ROLES = %w[owner admin member].freeze
  validates :role, inclusion: { in: ROLES }

  def owner?  = role == "owner"
  def admin?  = role.in?(%w[owner admin])
  def member? = role == "member"
end
```

### app/models/license_type.rb

```ruby
class LicenseType < ApplicationRecord
  acts_as_tenant :account

  has_many :plan_licenses
  has_many :plans, through: :plan_licenses

  validates :key,   presence: true, uniqueness: { scope: :account_id }
  validates :label, presence: true
  validates :unit,  presence: true
end
```

### app/models/credit_type.rb

```ruby
class CreditType < ApplicationRecord
  acts_as_tenant :account

  has_many :plan_credits
  has_many :plans, through: :plan_credits
  has_many :credit_snapshots
  has_many :credit_alerts

  RESET_CYCLES = %w[billing_cycle monthly yearly never].freeze

  validates :key,         presence: true, uniqueness: { scope: :account_id }
  validates :label,       presence: true
  validates :unit,        presence: true
  validates :reset_cycle, inclusion: { in: RESET_CYCLES }
end
```

### app/models/plan.rb

```ruby
class Plan < ApplicationRecord
  acts_as_tenant :account

  has_many :plan_licenses, dependent: :destroy
  has_many :license_types, through: :plan_licenses
  has_many :plan_credits,  dependent: :destroy
  has_many :credit_types,  through: :plan_credits
  has_many :subscriptions

  BILLING_CYCLES = %w[monthly yearly custom].freeze

  validates :name,          presence: true
  validates :price_cents,   numericality: { greater_than_or_equal_to: 0 }
  validates :billing_cycle, inclusion: { in: BILLING_CYCLES }

  scope :active,   -> { where(active: true, archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  def price_in_reais
    price_cents / 100.0
  end

  def archive!
    update!(active: false, archived_at: Time.current)
  end
end
```

### app/models/plan_license.rb

```ruby
class PlanLicense < ApplicationRecord
  belongs_to :plan
  belongs_to :license_type

  validates :quantity, numericality: { greater_than_or_equal_to: 0 }

  def unlimited?
    quantity == 0
  end
end
```

### app/models/plan_credit.rb

```ruby
class PlanCredit < ApplicationRecord
  belongs_to :plan
  belongs_to :credit_type

  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
end
```

### app/models/customer.rb

```ruby
class Customer < ApplicationRecord
  acts_as_tenant :account

  has_many :subscriptions
  has_many :charges
  has_many :credit_alerts

  STATUSES = %w[active suspended churned trial].freeze

  validates :name,   presence: true
  validates :email,  presence: true, uniqueness: { scope: :account_id }
  validates :status, inclusion: { in: STATUSES }

  scope :active,   -> { where(status: "active") }
  scope :churned,  -> { where(status: "churned") }
  scope :at_risk,  -> { where("health_score < ?", 40) }

  def active_subscription
    subscriptions.find_by(status: %w[active trialing past_due])
  end

  def current_period
    active_subscription&.subscription_periods&.current&.last
  end
end
```

### app/models/payment_gateway.rb

```ruby
class PaymentGateway < ApplicationRecord
  acts_as_tenant :account

  PROVIDERS = %w[stripe asaas].freeze

  validates :provider, inclusion: { in: PROVIDERS },
                       uniqueness: { scope: :account_id }
  validates :api_key_enc, presence: true

  scope :active, -> { where(active: true) }

  def api_key
    Rails.application.message_verifier(:gateway_keys).verify(api_key_enc)
  end

  def api_key=(raw_key)
    self.api_key_enc = Rails.application.message_verifier(:gateway_keys)
                            .generate(raw_key)
  end
end
```

### app/models/subscription.rb

```ruby
class Subscription < ApplicationRecord
  belongs_to :customer
  belongs_to :plan

  has_many :subscription_periods, dependent: :destroy
  has_many :charges
  has_many :subscription_plan_changes

  STATUSES = %w[active past_due cancelled trialing].freeze
  GATEWAYS = %w[stripe asaas].freeze

  validates :status,  inclusion: { in: STATUSES }
  validates :gateway, inclusion: { in: GATEWAYS }

  scope :active, -> { where(status: %w[active trialing]) }

  def current_period
    subscription_periods.current.last
  end

  def gateway_adapter
    Gateways::Base.for(gateway)
  end

  def cancel!
    gateway_adapter.cancel_subscription(gateway_subscription_id)
    update!(status: "cancelled", cancelled_at: Time.current)
    WebhookDispatchJob.perform_later(
      customer, "subscription.cancelled", {}
    )
  end

  def change_plan!(new_plan, changed_by:, reason: "admin_change")
    old_plan = plan
    gateway_adapter.update_subscription(gateway_subscription_id, new_plan)

    transaction do
      subscription_plan_changes.create!(
        from_plan:     old_plan,
        to_plan:       new_plan,
        reason:        reason,
        changed_by_id: changed_by.id
      )
      update!(plan: new_plan)
    end

    WebhookDispatchJob.perform_later(customer, "plan.changed", {
      previous_plan: { id: old_plan.id, name: old_plan.name },
      new_plan:      { id: new_plan.id, name: new_plan.name }
    })
  end
end
```

### app/models/subscription_period.rb

```ruby
class SubscriptionPeriod < ApplicationRecord
  belongs_to :subscription
  has_many :credit_snapshots, dependent: :destroy

  scope :current, -> {
    where("period_start <= ? AND period_end >= ?", Time.current, Time.current)
  }

  def credits_for(credit_type)
    credit_snapshots.find_by(credit_type: credit_type)
  end
end
```

### app/models/credit_snapshot.rb

```ruby
class CreditSnapshot < ApplicationRecord
  belongs_to :subscription_period
  belongs_to :credit_type

  validates :used,    numericality: { greater_than_or_equal_to: 0 }
  validates :limit,   numericality: { greater_than_or_equal_to: 0 }
  validates :balance, numericality: { greater_than_or_equal_to: 0 }

  before_save :calculate_fields

  private

  def calculate_fields
    self.balance       = [limit - used, 0].max
    self.usage_percent = limit > 0 ? (used.to_f / limit * 100).round(1) : 0.0
  end
end
```

### app/models/credit_alert.rb

```ruby
class CreditAlert < ApplicationRecord
  belongs_to :customer
  belongs_to :credit_type

  THRESHOLDS = [80, 95, 100].freeze

  validates :threshold, inclusion: { in: THRESHOLDS }
end
```

### app/models/charge.rb

```ruby
class Charge < ApplicationRecord
  belongs_to :customer
  belongs_to :subscription

  STATUSES = %w[pending paid failed refunded].freeze
  GATEWAYS = %w[stripe asaas].freeze

  validates :status,       inclusion: { in: STATUSES }
  validates :gateway,      inclusion: { in: GATEWAYS }
  validates :amount_cents, numericality: { greater_than: 0 }

  scope :paid,    -> { where(status: "paid") }
  scope :pending, -> { where(status: "pending") }
  scope :failed,  -> { where(status: "failed") }
end
```

### app/models/integration.rb

```ruby
class Integration < ApplicationRecord
  acts_as_tenant :account

  AVAILABLE_EVENTS = %w[
    subscription.activated subscription.cancelled subscription.past_due
    subscription.renewed subscription.trial_ending plan.changed
    payment.received payment.failed credits.threshold_reached
    credits.depleted credits.recharged license.updated
  ].freeze

  validates :name,   presence: true
  validates :url,    presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validates :secret, presence: true

  scope :active, -> { where(active: true) }

  before_create :generate_secret

  def events_for(event_name)
    events.include?(event_name)
  end

  private

  def generate_secret
    self.secret ||= SecureRandom.hex(32)
  end
end
```

### app/models/webhook_log.rb

```ruby
class WebhookLog < ApplicationRecord
  belongs_to :integration
  belongs_to :customer

  STATUSES = %w[pending delivered failed].freeze

  validates :event,  presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }
  scope :failed,  -> { where(status: "failed") }
  scope :due,     -> { pending.where("next_retry_at <= ?", Time.current) }
end
```

### app/models/api_key.rb

```ruby
class ApiKey < ApplicationRecord
  acts_as_tenant :account

  validates :name,         presence: true
  validates :token_digest, presence: true, uniqueness: true
  validates :last_four,    presence: true

  scope :active, -> { where(active: true) }

  def self.generate!(account:, name:, expires_at: nil)
    token_raw = "billing_#{SecureRandom.hex(32)}"

    key = ActsAsTenant.with_tenant(account) do
      create!(
        name:         name,
        token_digest: Digest::SHA256.hexdigest(token_raw),
        last_four:    token_raw.last(4),
        expires_at:   expires_at,
        active:       true
      )
    end

    [key, token_raw]
  end

  def self.find_by_token(raw_token)
    return nil if raw_token.blank?
    digest = Digest::SHA256.hexdigest(raw_token)
    active.find_by(token_digest: digest)
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end

  def revoke!
    update!(active: false)
  end
end
```

---

## 11. Configurar acts_as_tenant

**config/initializers/acts_as_tenant.rb:**

```ruby
ActsAsTenant.configure do |config|
  config.require_tenant = true
end
```

---

## 12. Controllers base

### app/controllers/application_controller.rb

```ruby
class ApplicationController < ActionController::Base
  set_current_tenant_through_filter
  before_action :authenticate_user!
  before_action :set_tenant

  private

  def set_tenant
    set_current_tenant(current_user.account)
  end

  def current_account
    current_user.account
  end
  helper_method :current_account
end
```

### app/controllers/api/v1/base_controller.rb

```ruby
class Api::V1::BaseController < ActionController::API
  before_action :authenticate_api_key!

  attr_reader :current_api_key, :current_account

  private

  def authenticate_api_key!
    raw_token = request.headers["Authorization"]&.sub("Bearer ", "")

    unless raw_token
      render json: { error: "Token não informado" }, status: :unauthorized
      return
    end

    @current_api_key = ApiKey.without_tenant { ApiKey.find_by_token(raw_token) }

    unless @current_api_key&.active? && !@current_api_key.expired?
      render json: { error: "Token inválido ou expirado" }, status: :unauthorized
      return
    end

    @current_account = @current_api_key.account
    ActsAsTenant.current_tenant = @current_account
    @current_api_key.touch_last_used!
  end
end
```

### app/controllers/webhooks/base_controller.rb

```ruby
class Webhooks::BaseController < ActionController::API
  skip_before_action :verify_authenticity_token

  private

  def verify_hmac_signature(secret, header_name: "X-Webhook-Signature")
    signature = request.headers[header_name]
    body      = request.body.read
    request.body.rewind

    expected = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, body)}"

    unless ActiveSupport::SecurityUtils.secure_compare(expected, signature.to_s)
      render json: { error: "Assinatura inválida" }, status: :unauthorized
      return false
    end
    true
  end
end
```

---

## 13. Service: criar conta + usuário

### app/services/accounts/create_service.rb

```ruby
class Accounts::CreateService
  Result = Struct.new(:success?, :account, :user, :errors)

  def self.call(params)
    new(params).call
  end

  def initialize(params)
    @params = params
  end

  def call
    ActiveRecord::Base.transaction do
      account = Account.create!(
        name: @params[:company_name]
      )

      user = account.users.create!(
        name:                  @params[:name],
        email:                 @params[:email],
        password:              @params[:password],
        password_confirmation: @params[:password_confirmation],
        role:                  "owner"
      )

      Seeds::DefaultTypesService.call(account)

      Result.new(true, account, user, [])
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.new(false, nil, nil, e.record.errors.full_messages)
  end
end
```

### app/services/seeds/default_types_service.rb

```ruby
class Seeds::DefaultTypesService
  def self.call(account)
    ActsAsTenant.with_tenant(account) do
      LicenseType.create!([
        { key: "user_licenses",  label: "Usuários",        unit: "usuário" },
        { key: "agent_licenses", label: "Agentes",         unit: "agente" },
        { key: "workspace_licenses", label: "Workspaces",  unit: "workspace" },
      ])

      CreditType.create!([
        { key: "coins",      label: "Coins",     unit: "coin",      reset_cycle: "billing_cycle" },
        { key: "ai_tokens",  label: "Tokens IA", unit: "token",     reset_cycle: "billing_cycle" },
        { key: "sms",        label: "SMS",       unit: "mensagem",  reset_cycle: "billing_cycle" },
        { key: "executions", label: "Execuções", unit: "execução",  reset_cycle: "billing_cycle" },
      ])
    end
  end
end
```

---

## 14. Controller de registro customizado

### app/controllers/users/registrations_controller.rb

```ruby
class Users::RegistrationsController < Devise::RegistrationsController
  skip_before_action :set_tenant

  def create
    result = Accounts::CreateService.call(
      company_name:          params[:user][:company_name],
      name:                  params[:user][:name],
      email:                 params[:user][:email],
      password:              params[:user][:password],
      password_confirmation: params[:user][:password_confirmation]
    )

    if result.success?
      sign_in(result.user)
      redirect_to root_path, notice: "Conta criada com sucesso!"
    else
      @errors = result.errors
      render :new, status: :unprocessable_entity
    end
  end
end
```

---

## 15. Gateway adapters

### app/services/gateways/base.rb

```ruby
module Gateways
  class Base
    class NotImplementedError < StandardError; end
    class GatewayError < StandardError
      attr_reader :code
      def initialize(msg, code: nil)
        super(msg)
        @code = code
      end
    end

    def create_customer(customer)              = raise NotImplementedError
    def create_subscription(customer, plan)   = raise NotImplementedError
    def cancel_subscription(sub_id)           = raise NotImplementedError
    def update_subscription(sub_id, new_plan) = raise NotImplementedError
    def create_charge(customer, amount_cents) = raise NotImplementedError

    def self.for(provider)
      case provider.to_s
      when "stripe" then Gateways::StripeAdapter.new
      when "asaas"  then Gateways::AsaasAdapter.new
      else raise ArgumentError, "Gateway '#{provider}' não suportado"
      end
    end
  end
end
```

### app/services/gateways/stripe_adapter.rb

```ruby
module Gateways
  class StripeAdapter < Base
    def initialize
      gateway = ActsAsTenant.current_tenant
                            .payment_gateways
                            .find_by!(provider: "stripe")
      Stripe.api_key = gateway.api_key
    end

    def create_customer(customer)
      result = Stripe::Customer.create(
        email:    customer.email,
        name:     customer.name,
        metadata: { external_id: customer.external_id }
      )
      customer.gateway_data["stripe"] ||= {}
      customer.gateway_data["stripe"]["customer_id"] = result.id
      customer.save!
      result
    rescue Stripe::StripeError => e
      raise GatewayError.new(e.message, code: e.code)
    end

    def create_subscription(customer, plan)
      price_id = plan.gateway_data.dig("stripe", "price_id")
      raise GatewayError, "Plano não configurado no Stripe (falta price_id)" unless price_id

      Stripe::Subscription.create(
        customer: customer.gateway_data.dig("stripe", "customer_id"),
        items:    [{ price: price_id }],
        metadata: { plan_id: plan.id, customer_id: customer.id }
      )
    rescue Stripe::StripeError => e
      raise GatewayError.new(e.message, code: e.code)
    end

    def cancel_subscription(gateway_sub_id)
      Stripe::Subscription.cancel(gateway_sub_id)
    rescue Stripe::StripeError => e
      raise GatewayError.new(e.message, code: e.code)
    end

    def update_subscription(gateway_sub_id, new_plan)
      sub      = Stripe::Subscription.retrieve(gateway_sub_id)
      price_id = new_plan.gateway_data.dig("stripe", "price_id")
      raise GatewayError, "Novo plano não configurado no Stripe" unless price_id

      Stripe::Subscription.update(gateway_sub_id, {
        items: [{ id: sub.items.data[0].id, price: price_id }]
      })
    rescue Stripe::StripeError => e
      raise GatewayError.new(e.message, code: e.code)
    end
  end
end
```

### app/services/gateways/asaas_adapter.rb

```ruby
module Gateways
  class AsaasAdapter < Base
    BASE_URL = "https://api.asaas.com/v3".freeze

    def initialize
      gateway = ActsAsTenant.current_tenant
                            .payment_gateways
                            .find_by!(provider: "asaas")
      @api_key = gateway.api_key
    end

    def create_customer(customer)
      response = post("/customers", {
        name:              customer.name,
        email:             customer.email,
        cpfCnpj:           customer.document,
        phone:             customer.phone,
        externalReference: customer.external_id
      })
      customer.gateway_data["asaas"] ||= {}
      customer.gateway_data["asaas"]["customer_id"] = response["id"]
      customer.save!
      response
    end

    def create_subscription(customer, plan)
      post("/subscriptions", {
        customer:          customer.gateway_data.dig("asaas", "customer_id"),
        billingType:       plan.gateway_data.dig("asaas", "billing_type") || "BOLETO",
        value:             plan.price_cents / 100.0,
        nextDueDate:       Date.tomorrow.strftime("%Y-%m-%d"),
        cycle:             asaas_cycle(plan.billing_cycle),
        description:       plan.name,
        externalReference: plan.id.to_s
      })
    end

    def cancel_subscription(gateway_sub_id)
      response = HTTParty.delete(
        "#{BASE_URL}/subscriptions/#{gateway_sub_id}",
        headers: headers
      )
      raise GatewayError, response.body unless response.success?
      response.parsed_response
    end

    def update_subscription(gateway_sub_id, new_plan)
      post("/subscriptions/#{gateway_sub_id}", {
        value: new_plan.price_cents / 100.0,
        cycle: asaas_cycle(new_plan.billing_cycle)
      })
    end

    private

    def asaas_cycle(billing_cycle)
      { "monthly" => "MONTHLY", "yearly" => "YEARLY" }.fetch(billing_cycle, "MONTHLY")
    end

    def post(path, body)
      response = HTTParty.post(
        "#{BASE_URL}#{path}",
        headers: headers,
        body:    body.to_json
      )
      raise GatewayError, response["errors"].to_s unless response.success?
      response.parsed_response
    end

    def headers
      {
        "access_token" => @api_key,
        "Content-Type" => "application/json"
      }
    end
  end
end
```

---

## 16. Controller de API Keys

### app/controllers/api_keys_controller.rb

```ruby
class ApiKeysController < ApplicationController
  before_action :require_admin!

  def index
    @api_keys = current_account.api_keys.active.order(created_at: :desc)
  end

  def create
    @api_key, @token_raw = ApiKey.generate!(
      account:    current_account,
      name:       params[:name],
      expires_at: params[:expires_at].presence
    )
    flash.now[:token] = @token_raw
    render :create
  end

  def destroy
    current_account.api_keys.find(params[:id]).revoke!
    redirect_to api_keys_path, notice: "Chave revogada com sucesso."
  end

  private

  def require_admin!
    redirect_to root_path, alert: "Acesso negado." unless current_user.admin?
  end
end
```

---

## 17. Rack::Attack

### config/initializers/rack_attack.rb

```ruby
class Rack::Attack
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?("/assets")
  end

  throttle("logins/ip", limit: 5, period: 20.seconds) do |req|
    req.ip if req.path == "/users/sign_in" && req.post?
  end

  throttle("api/ip", limit: 60, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  self.throttled_responder = lambda do |req|
    [429, { "Content-Type" => "application/json" },
     [{ error: "Muitas requisições. Tente novamente em breve." }.to_json]]
  end
end

Rails.application.config.middleware.use Rack::Attack
```

---

## 18. Verificar e rodar

```bash
# Verificar que tudo está OK
rails db:migrate
rails routes | grep -E "(api|webhook|plans|customers)"
rails runner "puts 'Rails OK'"

# Rodar servidor
rails server

# Em outro terminal, rodar Sidekiq
bundle exec sidekiq
```

---

## O que NÃO está no escopo desta fase

- Views/UI (fazer na Fase 2 junto com o dashboard)
- Webhooks de entrada (Asaas, Stripe) — Fase 2
- Webhook sender — Fase 2
- Endpoints da API de integração — Fase 2
- IA — Fase 3

---

## Próximo passo (Fase 2)

Após completar e validar esta fase:

1. Webhook receivers (Asaas e Stripe)
2. Webhook sender com retry via Sidekiq
3. Endpoints da API de integração
4. Dashboard básico com Vue

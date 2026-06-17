# Feature: Roles com Pundit Policies

## Hierarquia

```
owner (50) > admin (40) > manager (30) > seller (20) > member (10)
```

Dupla camada: Pundit no backend + auth.can no frontend (sidebar esconde).

---

## 1. Gemfile

```ruby
gem 'pundit'
```

```bash
bundle install
rails g pundit:install
# Cria app/policies/application_policy.rb
```

---

## 2. AccountUser — roles

```ruby
# app/models/account_user.rb
class AccountUser < ApplicationRecord
  belongs_to :account
  belongs_to :user

  ROLES = %w[owner admin manager seller member].freeze

  ROLE_LEVEL = {
    "owner"   => 50,
    "admin"   => 40,
    "manager" => 30,
    "seller"  => 20,
    "member"  => 10
  }.freeze

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :account_id }

  def level
    ROLE_LEVEL[role] || 0
  end

  def at_least?(minimum_role)
    level >= ROLE_LEVEL[minimum_role.to_s]
  end
end
```

---

## 3. User model — helpers

```ruby
# app/models/user.rb — adicionar:
def role_for(account)
  account_users.find_by(account: account)&.role
end

def account_user_for(account)
  account_users.find_by(account: account)
end

def at_least?(role, account = ActsAsTenant.current_tenant)
  return true if superadmin?
  account_user_for(account)&.at_least?(role) || false
end

def owner?(account = ActsAsTenant.current_tenant)
  at_least?(:owner, account)
end

def admin?(account = ActsAsTenant.current_tenant)
  at_least?(:admin, account)
end

def manager?(account = ActsAsTenant.current_tenant)
  at_least?(:manager, account)
end

def seller?(account = ActsAsTenant.current_tenant)
  at_least?(:seller, account)
end
```

---

## 4. ApplicationPolicy — base com role helpers

```ruby
# app/policies/application_policy.rb
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user   = user
    @record = record
  end

  # Defaults — ninguém pode nada
  def index?   = false
  def show?    = false
  def create?  = false
  def new?     = create?
  def update?  = false
  def edit?    = update?
  def destroy? = false

  # Scope padrão — retorna todos para o tenant atual
  class Scope
    def initialize(user, scope)
      @user  = user
      @scope = scope
    end

    def resolve
      scope.all
    end

    private

    attr_reader :user, :scope
  end

  private

  def owner?   = user.owner?
  def admin?   = user.admin?
  def manager? = user.manager?
  def seller?  = user.seller?
  def superadmin? = user.superadmin?
end
```

---

## 5. Policies por model

### app/policies/plan_policy.rb

```ruby
class PlanPolicy < ApplicationPolicy
  def index?   = true            # todos veem
  def show?    = true
  def create?  = admin?
  def update?  = admin?
  def destroy? = admin?
end
```

### app/policies/customer_policy.rb

```ruby
class CustomerPolicy < ApplicationPolicy
  def index?   = true            # todos veem
  def show?    = true
  def create?  = seller?         # seller+
  def update?  = seller?
  def destroy? = manager?        # manager+

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Todos os roles veem todos os clientes do tenant
      scope.all
    end
  end
end
```

### app/policies/subscription_policy.rb

```ruby
class SubscriptionPolicy < ApplicationPolicy
  def index?   = true
  def show?    = true
  def create?  = seller?         # seller+
  def update?  = seller?
  def destroy? = manager?        # manager+ (cancelar)
  def cancel?  = manager?        # alias explícito
end
```

### app/policies/product_policy.rb

```ruby
class ProductPolicy < ApplicationPolicy
  def index?   = true
  def show?    = true
  def create?  = admin?
  def update?  = admin?
  def destroy? = admin?
end
```

### app/policies/integration_policy.rb

```ruby
class IntegrationPolicy < ApplicationPolicy
  def index?   = manager?        # manager+ vê
  def show?    = manager?
  def create?  = admin?          # admin+ cria
  def update?  = admin?
  def destroy? = admin?
end
```

### app/policies/payment_gateway_policy.rb

```ruby
class PaymentGatewayPolicy < ApplicationPolicy
  def index?   = admin?
  def show?    = admin?
  def create?  = admin?
  def update?  = admin?
  def destroy? = admin?
end
```

### app/policies/license_type_policy.rb

```ruby
class LicenseTypePolicy < ApplicationPolicy
  def index?   = admin?
  def show?    = admin?
  def create?  = admin?
  def update?  = admin?
  def destroy? = admin?
end
```

### app/policies/credit_type_policy.rb

```ruby
class CreditTypePolicy < ApplicationPolicy
  def index?   = admin?
  def show?    = admin?
  def create?  = admin?
  def update?  = admin?
  def destroy? = admin?
end
```

### app/policies/feature_type_policy.rb

```ruby
class FeatureTypePolicy < ApplicationPolicy
  def index?   = admin?
  def show?    = admin?
  def create?  = admin?
  def update?  = admin?
  def destroy? = admin?
end
```

### app/policies/currency_policy.rb

```ruby
class CurrencyPolicy < ApplicationPolicy
  def index?   = admin?
  def show?    = admin?
  def create?  = admin?
  def update?  = admin?
  def destroy? = admin?
end
```

### app/policies/api_key_policy.rb

```ruby
class ApiKeyPolicy < ApplicationPolicy
  def index?   = admin?
  def show?    = admin?
  def create?  = admin?
  def destroy? = admin?
end
```

### app/policies/integration_api_key_policy.rb

```ruby
class IntegrationApiKeyPolicy < ApplicationPolicy
  def index?   = admin?
  def create?  = admin?
  def destroy? = admin?
end
```

### app/policies/account_user_policy.rb

```ruby
class AccountUserPolicy < ApplicationPolicy
  def index?   = manager?       # manager+ vê membros
  def show?    = manager?
  def create?  = admin?          # admin+ gerencia
  def update?  = admin?
  def destroy? = admin?

  # Não pode alterar role de alguém acima de si
  def change_role?
    return false unless admin?
    return false if record.role == "owner" && !owner?
    record.level < user.account_user_for(ActsAsTenant.current_tenant).level
  end
end
```

### app/policies/import_job_policy.rb

```ruby
class ImportJobPolicy < ApplicationPolicy
  def index?   = manager?
  def show?    = manager?
  def create?  = manager?
end
```

### app/policies/webhook_log_policy.rb

```ruby
class WebhookLogPolicy < ApplicationPolicy
  def index? = manager?
end
```

### app/policies/dashboard_policy.rb

```ruby
# Policy especial para o dashboard (não é um model)
class DashboardPolicy < ApplicationPolicy
  def full_stats?  = manager?    # manager+ vê MRR, ARR, etc.
  def basic_stats? = true        # todos veem contadores básicos
end
```

---

## 6. ApplicationController — integrar Pundit

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Pundit::Authorization

  after_action :verify_authorized, except: :index,
               unless: :skip_pundit?
  after_action :verify_policy_scoped, only: :index,
               unless: :skip_pundit?

  # Pundit usa current_user automaticamente
  # Rescue de não autorizado
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # ... existing code (set_current_account, inertia_share, etc.) ...

  # Helper para o frontend
  helper_method :can_policy?

  def can_policy?(action, record_or_class)
    policy(record_or_class).public_send("#{action}?")
  rescue NoMethodError
    false
  end

  private

  def user_not_authorized(exception)
    policy_name = exception.policy.class.to_s.underscore
    action      = exception.query

    if request.format.json?
      render json: { error: "Acesso negado." }, status: :forbidden
    else
      redirect_to root_path,
                  alert: "Você não tem permissão para esta ação.",
                  status: :see_other
    end
  end

  # Controllers que não usam Pundit (login, portal, etc.)
  def skip_pundit?
    devise_controller? ||
    is_a?(Portal::BaseController) ||
    is_a?(Superadmin::BaseController) ||
    is_a?(Api::V1::BaseController) ||
    is_a?(Webhooks::BaseController)
  end

  # Atualizar inertia_share com permissões via policies
  inertia_share do
    {
      auth: {
        user: current_user ? {
          id:         current_user.id,
          name:       current_user.name,
          email:      current_user.email,
          superadmin: current_user.superadmin?,
          role:       current_account ?
                      current_user.role_for(current_account) : nil
        } : nil,
        account:  current_account ? {
          id:   current_account.id,
          name: current_account.name,
          slug: current_account.slug
        } : nil,
        accounts: current_user&.accounts&.map { |a|
          { id: a.id, name: a.name }
        } || [],
        impersonating: session[:impersonating].present?,
        can: current_user && current_account ? build_permissions : {}
      },
      flash: {
        notice: flash[:notice],
        alert:  flash[:alert]
      }
    }
  end

  def build_permissions
    {
      # Dashboard
      view_full_dashboard:   DashboardPolicy.new(current_user, nil).full_stats?,

      # Clientes
      view_customers:        CustomerPolicy.new(current_user, nil).index?,
      create_customers:      CustomerPolicy.new(current_user, nil).create?,
      manage_customers:      CustomerPolicy.new(current_user, nil).destroy?,

      # Assinaturas
      view_subscriptions:    SubscriptionPolicy.new(current_user, nil).index?,
      create_subscriptions:  SubscriptionPolicy.new(current_user, nil).create?,
      cancel_subscriptions:  SubscriptionPolicy.new(current_user, nil).cancel?,

      # Planos
      view_plans:            PlanPolicy.new(current_user, nil).index?,
      manage_plans:          PlanPolicy.new(current_user, nil).create?,

      # Produtos
      view_products:         ProductPolicy.new(current_user, nil).index?,
      manage_products:       ProductPolicy.new(current_user, nil).create?,

      # Importação
      import_customers:      ImportJobPolicy.new(current_user, nil).create?,

      # Integrações
      view_integrations:     IntegrationPolicy.new(current_user, nil).index?,
      manage_integrations:   IntegrationPolicy.new(current_user, nil).create?,

      # Settings (gateways, tipos, moedas, api keys)
      manage_settings:       PaymentGatewayPolicy.new(current_user, nil).index?,

      # Membros
      view_members:          AccountUserPolicy.new(current_user, nil).index?,
      manage_members:        AccountUserPolicy.new(current_user, nil).create?,

      # Webhook logs
      view_webhook_logs:     WebhookLogPolicy.new(current_user, nil).index?,
    }
  end
end
```

---

## 7. Controllers — usar authorize

### PlansController

```ruby
class PlansController < ApplicationController
  before_action :set_plan, only: [:show, :edit, :update, :destroy]

  def index
    @plans = policy_scope(Plan).order(:name)
    render inertia: "Plans/Index", props: {
      plans: @plans.map { |p| serialize_plan(p) }
    }
  end

  def show
    authorize @plan
    render inertia: "Plans/Show", props: { plan: serialize_plan(@plan) }
  end

  def new
    authorize Plan
    render inertia: "Plans/Form", props: { plan: {}, errors: {} }
  end

  def create
    authorize Plan
    @plan = Plan.new(plan_params)
    if @plan.save
      redirect_to plans_path, notice: "Plano criado.", status: :see_other
    else
      render inertia: "Plans/Form", props: {
        plan: plan_params, errors: @plan.errors.full_messages
      }
    end
  end

  def edit
    authorize @plan
    render inertia: "Plans/Form", props: {
      plan: serialize_plan(@plan), errors: {}
    }
  end

  def update
    authorize @plan
    if @plan.update(plan_params)
      redirect_to plans_path, notice: "Plano atualizado.", status: :see_other
    else
      render inertia: "Plans/Form", props: {
        plan: serialize_plan(@plan), errors: @plan.errors.full_messages
      }
    end
  end

  def destroy
    authorize @plan
    @plan.destroy!
    redirect_to plans_path, notice: "Plano removido.", status: :see_other
  rescue ActiveRecord::InvalidForeignKey
    redirect_to plans_path, alert: "Não é possível remover: em uso.",
                status: :see_other
  end

  private

  def set_plan
    @plan = Plan.find(params[:id])
  end
end
```

### CustomersController

```ruby
class CustomersController < ApplicationController
  before_action :set_customer, only: [:show, :edit, :update, :destroy]

  def index
    @customers = policy_scope(Customer).order(created_at: :desc)
    render inertia: "Customers/Index", props: {
      customers: @customers.map { |c| serialize_customer(c) }
    }
  end

  def show
    authorize @customer
    # ... existing code
  end

  def new
    authorize Customer
    # ... existing code
  end

  def create
    authorize Customer
    # ... existing code
  end

  def edit
    authorize @customer
    # ... existing code
  end

  def update
    authorize @customer
    # ... existing code
  end

  def destroy
    authorize @customer
    @customer.destroy!
    redirect_to customers_path, notice: "Cliente removido.",
                status: :see_other
  end

  private

  def set_customer
    @customer = Customer.find(params[:id])
  end
end
```

### SubscriptionsController

```ruby
class SubscriptionsController < ApplicationController
  before_action :set_customer
  before_action :set_subscription, only: [:show, :edit, :update, :destroy]

  def new
    authorize Subscription
    # ... existing code
  end

  def create
    authorize Subscription
    # ... existing code
  end

  def edit
    authorize @subscription
    # ... existing code
  end

  def update
    authorize @subscription
    # ... existing code
  end

  def destroy
    authorize @subscription, :cancel?
    # ... cancel logic
  end

  private

  def set_customer
    @customer = Customer.find(params[:customer_id])
  end

  def set_subscription
    @subscription = @customer.subscriptions.find(params[:id])
  end
end
```

### Padrão para settings controllers (todos iguais)

```ruby
# Aplicar em: PaymentGatewaysController, LicenseTypesController,
# CreditTypesController, FeatureTypesController, CurrenciesController,
# ApiKeysController

# Exemplo: PaymentGatewaysController
class PaymentGatewaysController < ApplicationController
  before_action :set_gateway, only: [:show, :edit, :update, :destroy]

  def index
    authorize PaymentGateway
    # ...
  end

  def new
    authorize PaymentGateway
    # ...
  end

  def create
    authorize PaymentGateway
    # ...
  end

  def edit
    authorize @gateway
    # ...
  end

  def update
    authorize @gateway
    # ...
  end

  def destroy
    authorize @gateway
    # ...
  end
end
```

### IntegrationsController

```ruby
class IntegrationsController < ApplicationController
  before_action :set_integration, only: [:show, :edit, :update, :destroy]

  def index
    authorize Integration
    # ...
  end

  def show
    authorize @integration
    # ...
  end

  def new
    authorize Integration
    # ...
  end

  def create
    authorize Integration
    # ...
  end

  def edit
    authorize @integration
    # ...
  end

  def update
    authorize @integration
    # ...
  end

  def destroy
    authorize @integration
    # ...
  end
end
```

### AccountUsersController

```ruby
class AccountUsersController < ApplicationController
  before_action :set_account_user, only: [:edit, :update, :destroy]

  def index
    authorize AccountUser
    # ...
  end

  def new
    authorize AccountUser
    # ...
  end

  def create
    authorize AccountUser
    # ...
  end

  def update
    authorize @account_user, :change_role?

    new_role = params[:role]
    my_au    = current_user.account_user_for(current_account)

    # Não pode promover acima do próprio nível
    if AccountUser::ROLE_LEVEL[new_role].to_i >= my_au.level
      redirect_to account_users_path,
                  alert: "Você não pode atribuir este role.",
                  status: :see_other
      return
    end

    @account_user.update!(role: new_role)
    redirect_to account_users_path, notice: "Role atualizado.",
                status: :see_other
  end

  def destroy
    authorize @account_user
    # ...
  end
end
```

### ImportsController

```ruby
class ImportsController < ApplicationController
  def index
    authorize ImportJob
    # ...
  end

  def create
    authorize ImportJob
    # ...
  end

  def show
    @import_job = ImportJob.find(params[:id])
    authorize @import_job
    # ...
  end
end
```

### DashboardController

```ruby
class DashboardController < ApplicationController
  def index
    # Não precisa de authorize porque todos acessam
    # Mas stats diferem por role
    stats = if policy(:dashboard).full_stats?
              DashboardStatsService.full_stats
            else
              DashboardStatsService.basic_stats
            end

    render inertia: "Dashboard/Index", props: { stats: }
  end
end
```

---

## 8. Sidebar.vue — esconder por permissão

```vue
<!-- app/javascript/components/Layout/Sidebar.vue -->
<template>
  <nav class="w-60 bg-gray-900 flex flex-col flex-shrink-0 select-none">
    <!-- Logo -->
    <div class="h-14 flex items-center gap-2.5 px-4 border-b border-white/10">
      <div
        class="w-7 h-7 rounded-lg bg-brand-500 flex items-center
                  justify-center flex-shrink-0"
      >
        <svg
          class="w-4 h-4 text-white"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          stroke-width="2"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0
                   00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z"
          />
        </svg>
      </div>
      <span class="text-white font-semibold text-sm tracking-wide"
        >Billing</span
      >
    </div>

    <!-- Links -->
    <div class="flex-1 overflow-y-auto py-3 px-2 space-y-0.5">
      <NavLink href="/" icon="dashboard" label="Dashboard" :exact="true" />

      <!-- GESTÃO -->
      <template v-if="can.view_customers || can.view_plans">
        <SideSection label="Gestão" />
        <NavLink
          v-if="can.view_subscriptions"
          href="/subscriptions"
          icon="subscriptions"
          label="Assinaturas"
        />
        <NavLink
          v-if="can.view_customers"
          href="/customers"
          icon="customers"
          label="Clientes"
        />
        <NavLink
          v-if="can.view_plans"
          href="/plans"
          icon="plans"
          label="Planos"
        />
        <NavLink
          v-if="can.view_products"
          href="/products"
          icon="products"
          label="Produtos"
        />
        <NavLink
          v-if="can.import_customers"
          href="/imports"
          icon="import"
          label="Importar clientes"
        />
      </template>

      <!-- CONFIGURAÇÕES — admin+ -->
      <template v-if="can.view_integrations || can.manage_settings">
        <SideSection label="Configurações" />
        <NavLink
          v-if="can.view_integrations"
          href="/integrations"
          icon="integrations"
          label="Integrações"
        />
        <NavLink
          v-if="can.manage_settings"
          href="/api_keys"
          icon="apikeys"
          label="API Keys"
        />
        <NavLink
          v-if="can.manage_settings"
          href="/payment_gateways"
          icon="gateways"
          label="Gateways"
        />
        <NavLink
          v-if="can.manage_settings"
          href="/currencies"
          icon="currencies"
          label="Moedas"
        />
      </template>

      <!-- TIPOS — admin+ -->
      <template v-if="can.manage_settings">
        <SideSection label="Tipos" />
        <NavLink
          href="/license_types"
          icon="license"
          label="Tipos de licença"
        />
        <NavLink href="/credit_types" icon="credits" label="Tipos de crédito" />
        <NavLink href="/feature_types" icon="features" label="Features" />
      </template>

      <!-- EQUIPE — manager+ -->
      <template v-if="can.view_members">
        <SideSection label="Equipe" />
        <NavLink href="/account_users" icon="sa_users" label="Membros" />
      </template>

      <!-- SUPERADMIN -->
      <template v-if="auth.user?.superadmin">
        <SideSection label="SuperAdmin" variant="warning" />
        <NavLink href="/superadmin" icon="sa_dashboard" label="Dashboard" />
        <NavLink
          href="/superadmin/accounts"
          icon="sa_accounts"
          label="Contas"
        />
        <NavLink href="/superadmin/users" icon="sa_users" label="Usuários" />
        <NavLink
          href="/superadmin/super_admins"
          icon="sa_admins"
          label="SuperAdmins"
        />
        <a
          href="/sidekiq"
          target="_blank"
          class="flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm
                  text-gray-400 hover:bg-white/5 hover:text-gray-200
                  transition-all duration-150 group"
        >
          <span class="flex-shrink-0 w-4 h-4 flex items-center justify-center">
            <span class="w-4 h-4 block" v-html="sidekiqIcon"></span>
          </span>
          <span class="truncate">Sidekiq</span>
          <svg
            class="w-3 h-3 text-gray-500 ml-auto opacity-0
                      group-hover:opacity-100 transition-opacity"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="2"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0
                     002-2v-4M14 4h6m0 0v6m0-6L10 14"
            />
          </svg>
        </a>
      </template>
    </div>

    <!-- Seletor de conta -->
    <div
      v-if="auth.accounts?.length > 1"
      class="px-3 py-2 border-t border-white/10"
    >
      <select
        class="w-full text-xs bg-gray-800 text-gray-300 border border-white/10
               rounded-lg px-2 py-1.5 focus:ring-1 focus:ring-brand-500
               focus:outline-none"
        :value="auth.account?.id"
        @change="switchAccount($event.target.value)"
      >
        <option v-for="a in auth.accounts" :key="a.id" :value="a.id">
          {{ a.name }}
        </option>
      </select>
    </div>

    <!-- Usuário -->
    <div class="border-t border-white/10 px-3 py-3">
      <div class="flex items-center gap-2.5">
        <div
          class="w-8 h-8 rounded-full bg-brand-600 flex items-center
                    justify-center text-white text-xs font-semibold flex-shrink-0"
        >
          {{ auth.user?.name?.charAt(0).toUpperCase() }}
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-xs font-medium text-white truncate leading-tight">
            {{ auth.user?.name }}
          </p>
          <p class="text-xs text-gray-400 truncate leading-tight">
            {{ roleLabel }} · {{ auth.account?.name }}
          </p>
        </div>
        <Link
          :href="route('logout')"
          method="delete"
          as="button"
          class="p-1 rounded text-gray-500 hover:text-gray-300
                     hover:bg-white/5 transition-colors flex-shrink-0"
          title="Sair"
        >
          <svg
            class="w-4 h-4"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="2"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3
                     3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"
            />
          </svg>
        </Link>
      </div>
    </div>
  </nav>
</template>

<script setup>
import { computed } from "vue";
import { Link, usePage, router } from "@inertiajs/vue3";
import NavLink from "./NavLink.vue";
import SideSection from "./SideSection.vue";

const page = usePage();
const auth = computed(() => page.props.auth);
const can = computed(() => page.props.auth?.can || {});

const roleLabel = computed(
  () =>
    ({
      owner: "Owner",
      admin: "Admin",
      manager: "Manager",
      seller: "Vendedor",
      member: "Membro",
    })[auth.value.user?.role] || "",
);

const switchAccount = (id) =>
  router.post("/account_switch", { account_id: id });

const route = (name) =>
  ({
    logout: "/users/sign_out",
  })[name] || "/";

const sidekiqIcon = `<svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
  <path stroke-linecap="round" stroke-linejoin="round"
    d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0
       012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002
       2h14a2 2 0 002-2v-4a2 2 0 00-2-2m-2-4h.01M17 16h.01"/>
</svg>`;
</script>
```

---

## 9. Botões condicionais nos componentes

### Composable: usePermissions

```js
// app/javascript/composables/usePermissions.js
import { computed } from "vue";
import { usePage } from "@inertiajs/vue3";

export function usePermissions() {
  const page = usePage();
  const can = computed(() => page.props.auth?.can || {});
  const role = computed(() => page.props.auth?.user?.role);

  return { can, role };
}
```

### Uso nos componentes

```vue
<!-- Customers/Index.vue -->
<template>
  <AppLayout>
    <div class="page-header">
      <h2 class="page-title">Clientes</h2>
      <Link
        v-if="can.create_customers"
        href="/customers/new"
        class="btn-primary"
      >
        Novo cliente
      </Link>
    </div>

    <!-- Na tabela: -->
    <td class="text-right flex gap-2 justify-end">
      <Link :href="`/customers/${c.id}`" class="btn-secondary btn-sm">
        Ver
      </Link>
      <Link
        v-if="can.create_customers"
        :href="`/customers/${c.id}/edit`"
        class="btn-secondary btn-sm"
      >
        Editar
      </Link>
      <ConfirmButton
        v-if="can.manage_customers"
        :message="`Remover ${c.name}?`"
        @confirm="destroy(c.id)"
      >
        Remover
      </ConfirmButton>
    </td>
  </AppLayout>
</template>

<script setup>
import { usePermissions } from "@/composables/usePermissions";
const { can } = usePermissions();
</script>
```

```vue
<!-- Plans/Index.vue -->
<Link v-if="can.manage_plans" href="/plans/new" class="btn-primary">
  Novo plano
</Link>

<!-- Botão editar vs ver: -->
<Link
  v-if="can.manage_plans"
  :href="`/plans/${p.id}/edit`"
  class="btn-secondary btn-sm"
>
  Editar
</Link>
<Link v-else :href="`/plans/${p.id}`" class="btn-secondary btn-sm">
  Ver
</Link>
```

```vue
<!-- Subscriptions — cancelar só manager+ -->
<ConfirmButton
  v-if="can.cancel_subscriptions"
  :message="`Cancelar assinatura de ${customer.name}?`"
  @confirm="cancelSubscription"
>
  Cancelar assinatura
</ConfirmButton>
```

---

## 10. AccountUsers/Form.vue — roles disponíveis

```vue
<div>
  <label class="form-label">Permissão</label>
  <select v-model="form.role" class="form-input">
    <option v-for="r in availableRoles" :key="r.value" :value="r.value">
      {{ r.label }}
    </option>
  </select>
  <p class="text-xs text-gray-500 mt-1">{{ roleDesc }}</p>
</div>

<script setup>
import { computed } from "vue";
import { usePermissions } from "@/composables/usePermissions";

const { role: myRole } = usePermissions();

const allRoles = [
  {
    value: "owner",
    label: "Owner",
    level: 50,
    desc: "Acesso total. Pode excluir a conta.",
  },
  {
    value: "admin",
    label: "Admin",
    level: 40,
    desc: "Configura planos, gateways, integrações e tipos.",
  },
  {
    value: "manager",
    label: "Manager",
    level: 30,
    desc: "Gerencia clientes, assinaturas e importações.",
  },
  {
    value: "seller",
    label: "Vendedor",
    level: 20,
    desc: "Cria clientes e assinaturas. Não cancela nem deleta.",
  },
  { value: "member", label: "Membro", level: 10, desc: "Apenas visualização." },
];

const myLevel = computed(() => {
  const me = allRoles.find((r) => r.value === myRole.value);
  return me?.level || 0;
});

// Só pode atribuir roles abaixo do próprio
const availableRoles = computed(() =>
  allRoles.filter((r) => r.level < myLevel.value),
);

const roleDesc = computed(
  () => allRoles.find((r) => r.value === form.role)?.desc || "",
);
</script>
```

---

## 11. Specs

```ruby
# spec/policies/plan_policy_spec.rb
require 'rails_helper'

RSpec.describe PlanPolicy do
  let(:account) { create(:account) }
  let(:plan)    { create(:plan, account: account) }

  subject { described_class.new(user, plan) }

  before { ActsAsTenant.current_tenant = account }

  def user_with_role(role)
    u = create(:user)
    create(:account_user, account: account, user: u, role: role)
    u
  end

  context 'owner' do
    let(:user) { user_with_role('owner') }
    it { is_expected.to permit_actions([:index, :show, :create, :update, :destroy]) }
  end

  context 'admin' do
    let(:user) { user_with_role('admin') }
    it { is_expected.to permit_actions([:index, :show, :create, :update, :destroy]) }
  end

  context 'manager' do
    let(:user) { user_with_role('manager') }
    it { is_expected.to permit_actions([:index, :show]) }
    it { is_expected.to forbid_actions([:create, :update, :destroy]) }
  end

  context 'seller' do
    let(:user) { user_with_role('seller') }
    it { is_expected.to permit_actions([:index, :show]) }
    it { is_expected.to forbid_actions([:create, :update, :destroy]) }
  end

  context 'member' do
    let(:user) { user_with_role('member') }
    it { is_expected.to permit_actions([:index, :show]) }
    it { is_expected.to forbid_actions([:create, :update, :destroy]) }
  end
end

# spec/policies/customer_policy_spec.rb
require 'rails_helper'

RSpec.describe CustomerPolicy do
  let(:account)  { create(:account) }
  let(:customer) { create(:customer, account: account) }

  subject { described_class.new(user, customer) }

  before { ActsAsTenant.current_tenant = account }

  def user_with_role(role)
    u = create(:user)
    create(:account_user, account: account, user: u, role: role)
    u
  end

  context 'seller' do
    let(:user) { user_with_role('seller') }
    it { is_expected.to permit_actions([:index, :show, :create, :update]) }
    it { is_expected.to forbid_action(:destroy) }
  end

  context 'member' do
    let(:user) { user_with_role('member') }
    it { is_expected.to permit_actions([:index, :show]) }
    it { is_expected.to forbid_actions([:create, :update, :destroy]) }
  end
end

# spec/policies/subscription_policy_spec.rb
require 'rails_helper'

RSpec.describe SubscriptionPolicy do
  let(:account)      { create(:account) }
  let(:subscription) { create(:subscription) }

  subject { described_class.new(user, subscription) }

  before { ActsAsTenant.current_tenant = account }

  def user_with_role(role)
    u = create(:user)
    create(:account_user, account: account, user: u, role: role)
    u
  end

  context 'seller' do
    let(:user) { user_with_role('seller') }
    it { is_expected.to permit_actions([:index, :show, :create, :update]) }
    it { is_expected.to forbid_action(:cancel) }
  end

  context 'manager' do
    let(:user) { user_with_role('manager') }
    it { is_expected.to permit_action(:cancel) }
  end
end

# Adicionar gem para matchers de policy:
# Gemfile (group :test):
gem 'pundit-matchers'
```

---

## Resumo

```
┌────────────────────────┬───────┬───────┬─────────┬────────┬────────┐
│                        │ owner │ admin │ manager │ seller │ member │
├────────────────────────┼───────┼───────┼─────────┼────────┼────────┤
│ Dashboard completo     │   ✓   │   ✓   │    ✓    │   ✕    │   ✕    │
│ Clientes: ver          │   ✓   │   ✓   │    ✓    │   ✓    │   ✓    │
│ Clientes: criar/editar │   ✓   │   ✓   │    ✓    │   ✓    │   ✕    │
│ Clientes: deletar      │   ✓   │   ✓   │    ✓    │   ✕    │   ✕    │
│ Assinaturas: criar     │   ✓   │   ✓   │    ✓    │   ✓    │   ✕    │
│ Assinaturas: cancelar  │   ✓   │   ✓   │    ✓    │   ✕    │   ✕    │
│ Planos: CRUD           │   ✓   │   ✓   │    ✕    │   ✕    │   ✕    │
│ Settings (gw/tipos)    │   ✓   │   ✓   │    ✕    │   ✕    │   ✕    │
│ Integrações: ver       │   ✓   │   ✓   │    ✓    │   ✕    │   ✕    │
│ Integrações: CRUD      │   ✓   │   ✓   │    ✕    │   ✕    │   ✕    │
│ Membros: ver           │   ✓   │   ✓   │    ✓    │   ✕    │   ✕    │
│ Membros: gerenciar     │   ✓   │   ✓   │    ✕    │   ✕    │   ✕    │
│ Excluir conta          │   ✓   │   ✕   │    ✕    │   ✕    │   ✕    │
└────────────────────────┴───────┴───────┴─────────┴────────┴────────┘
```

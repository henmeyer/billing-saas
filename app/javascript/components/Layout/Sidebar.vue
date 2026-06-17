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
      <span class="text-white font-semibold text-sm tracking-wide">Billing</span>
    </div>

    <!-- Links -->
    <div class="flex-1 overflow-y-auto py-3 px-2 space-y-0.5">
      <!-- Dashboard -->
      <NavLink href="/" icon="dashboard" label="Dashboard" :exact="true" />

      <!-- GESTÃO -->
      <template v-if="can.view_customers || can.view_plans || can.view_subscriptions || can.view_products">
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

      <!-- CONFIGURAÇÕES — manager+ para integrações, admin+ para settings -->
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
        <NavLink href="/license_types" icon="license" label="Tipos de licença" />
        <NavLink href="/credit_types" icon="credits" label="Tipos de crédito" />
        <NavLink href="/feature_types" icon="features" label="Features" />
      </template>

      <!-- EQUIPE — manager+ -->
      <template v-if="can.view_members">
        <SideSection label="Equipe" />
        <NavLink href="/account_users" icon="sa_users" label="Colaboradores" />
      </template>

      <!-- SUPERADMIN -->
      <template v-if="auth.user?.superadmin">
        <SideSection label="SuperAdmin" variant="warning" />
        <NavLink href="/superadmin" icon="sa_dashboard" label="Dashboard" :exact="true" />
        <NavLink href="/superadmin/accounts" icon="sa_accounts" label="Contas" />
        <NavLink href="/superadmin/users" icon="sa_users" label="Usuários" />
        <NavLink href="/superadmin/super_admins" icon="sa_admins" label="SuperAdmins" />
        <a
          href="/sidekiq"
          target="_blank"
          class="flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm
                 text-gray-400 hover:bg-white/5 hover:text-gray-200
                 transition-all duration-150 group"
        >
          <span class="flex-shrink-0 w-4 h-4 flex items-center justify-center">
            <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75" class="w-4 h-4">
              <path stroke-linecap="round" stroke-linejoin="round"
                d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v4a2 2 0
                   01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h14a2 2 0 002-2v-4a2 2 0
                   00-2-2m-2-4h.01M17 16h.01" />
            </svg>
          </span>
          <span class="truncate">Sidekiq</span>
          <svg
            class="w-3 h-3 text-gray-500 ml-auto opacity-0 group-hover:opacity-100 transition-opacity"
            fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"
          >
            <path stroke-linecap="round" stroke-linejoin="round"
              d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
          </svg>
        </a>
      </template>
    </div>

    <!-- Seletor de conta (múltiplas contas) -->
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
          href="/users/sign_out"
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
const can  = computed(() => page.props.auth?.can || {});

const roleLabel = computed(() =>
  ({
    owner:   "Owner",
    admin:   "Admin",
    manager: "Manager",
    seller:  "Vendedor",
    member:  "Colaborador",
  })[auth.value?.user?.role] || ""
);

const switchAccount = (accountId) =>
  router.post("/account_switch", { account_id: accountId });
</script>

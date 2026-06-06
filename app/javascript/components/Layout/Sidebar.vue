<template>
  <nav class="w-56 bg-gray-900 flex flex-col flex-shrink-0">
    <!-- Logo -->
    <div class="h-14 flex items-center px-4 border-b border-gray-700">
      <span class="text-white font-semibold text-sm tracking-wide"
        >💳 Billing</span
      >
    </div>

    <!-- Links -->
    <div class="flex-1 py-4 overflow-y-auto">
      <div class="space-y-0.5 px-2">
        <NavLink href="/" icon="◻" label="Dashboard" />

        <p
          class="text-xs font-medium text-gray-500 uppercase tracking-wider px-2 pt-4 pb-1"
        >
          Gestão
        </p>

        <NavLink href="/subscriptions" icon="↻" label="Assinaturas" />
        <NavLink href="/customers" icon="◉" label="Clientes" />
        <NavLink href="/plans" icon="▤" label="Planos" />
        <NavLink href="/products" icon="▦" label="Produtos" />

        <p
          class="text-xs font-medium text-gray-500 uppercase tracking-wider px-2 pt-4 pb-1"
        >
          Configurações
        </p>

        <NavLink href="/integrations" icon="⇄" label="Integrações" />
        <NavLink href="/api_keys" icon="⚷" label="API Keys" />
        <NavLink href="/license_types" icon="▣" label="Tipos de licença" />
        <NavLink href="/credit_types" icon="◈" label="Tipos de crédito" />
        <NavLink href="/feature_types" icon="◆" label="Features" />
        <NavLink href="/payment_gateways" icon="▷" label="Gateways" />
      </div>
    </div>

    <!-- Usuário -->
    <div class="border-t border-gray-700 px-4 py-3">
      <div class="flex items-center gap-3">
        <div
          class="w-7 h-7 rounded-full bg-brand-600 flex items-center justify-center text-white text-xs font-medium flex-shrink-0"
        >
          {{ auth?.user?.name?.charAt(0).toUpperCase() }}
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-xs font-medium text-white truncate">
            {{ auth?.user?.name }}
          </p>
          <p class="text-xs text-gray-400 truncate">
            {{ auth?.account?.name }}
          </p>
        </div>
      </div>
      <Link
        href="/users/sign_out"
        method="delete"
        as="button"
        class="mt-2 text-xs text-gray-400 hover:text-white transition-colors"
      >
        Sair
      </Link>
    </div>
  </nav>
</template>

<script setup>
import { Link } from "@inertiajs/vue3";
import NavLink from "./NavLink.vue";

defineProps({
  auth: Object,
});
</script>

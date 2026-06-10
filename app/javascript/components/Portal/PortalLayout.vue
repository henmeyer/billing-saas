<template>
  <div
    class="min-h-screen bg-gray-50"
    :style="{ '--portal-primary': branding.primary_color || '#6366f1' }"
  >
    <!-- Header -->
    <header class="bg-white border-b border-gray-200">
      <div
        class="max-w-4xl mx-auto px-4 py-3 flex items-center justify-between"
      >
        <div class="flex items-center gap-3">
          <img
            v-if="branding.logo_url"
            :src="branding.logo_url"
            class="h-8 object-contain"
            :alt="branding.company_name"
          />
          <span v-else class="text-lg font-semibold text-gray-900">
            {{ branding.company_name || "Portal" }}
          </span>
        </div>

        <nav class="flex items-center gap-1">
          <PortalNavLink :href="portalPath('')" label="Meu plano" />
          <PortalNavLink
            v-if="portalConfig.allow_plan_change"
            :href="portalPath('/plans')"
            label="Planos"
          />
          <PortalNavLink
            v-if="portalConfig.allow_buy_products"
            :href="portalPath('/products')"
            label="Comprar"
          />
          <PortalNavLink
            v-if="portalConfig.show_invoice_history"
            :href="portalPath('/invoices')"
            label="Faturas"
          />
        </nav>

        <div class="flex items-center gap-3 text-sm">
          <span class="text-gray-500">{{ customer.name }}</span>
          <Link
            :href="portalPath('/logout')"
            method="delete"
            as="button"
            class="text-xs text-gray-400 hover:text-gray-600"
          >
            Sair
          </Link>
        </div>
      </div>
    </header>

    <!-- Flash -->
    <div v-if="flash.notice" class="max-w-4xl mx-auto mt-4 px-4">
      <div class="bg-green-50 text-green-700 text-sm px-4 py-2.5 rounded-lg">
        {{ flash.notice }}
      </div>
    </div>
    <div v-if="flash.alert" class="max-w-4xl mx-auto mt-4 px-4">
      <div class="bg-red-50 text-red-700 text-sm px-4 py-2.5 rounded-lg">
        {{ flash.alert }}
      </div>
    </div>

    <!-- Content -->
    <main class="max-w-4xl mx-auto px-4 py-6">
      <slot />
    </main>
  </div>
</template>

<script setup>
import { computed } from "vue";
import { Link, usePage } from "@inertiajs/vue3";
import PortalNavLink from "./PortalNavLink.vue";

defineProps({
  customer: { type: Object, default: () => ({}) },
  branding: { type: Object, default: () => ({}) },
  portalConfig: { type: Object, default: () => ({}) },
});

const page = usePage();
const flash = computed(() => page.props.flash || {});
const token = computed(() => page.props.portal_token);

const portalPath = (path) => `/portal/${token.value}${path}`;
</script>

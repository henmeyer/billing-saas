<template>
  <PortalLayout
    :customer="$page.props.customer"
    :branding="branding"
    :portal-config="portalConfig"
  >
    <h1 class="text-xl font-semibold text-gray-900 mb-6">Comprar pacotes</h1>

    <div v-if="!products.length" class="card">
      <div class="card-body text-center py-12 text-gray-400">
        Nenhum pacote disponível no momento.
      </div>
    </div>

    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <div v-for="p in products" :key="p.id" class="card">
        <div class="card-body space-y-3">
          <div>
            <h3 class="font-semibold text-gray-900">{{ p.name }}</h3>
            <p v-if="p.description" class="text-sm text-gray-500 mt-0.5">
              {{ p.description }}
            </p>
          </div>

          <div class="bg-gray-50 rounded-lg px-3 py-2 text-sm">
            <span class="text-gray-500">
              {{ fmtNum(p.credit_quantity) }} {{ p.credit_unit }}s
            </span>
          </div>

          <div class="flex items-center justify-between pt-2">
            <span class="text-xl font-bold text-gray-900">
              {{ fmt(p.price_cents) }}
            </span>
            <ConfirmButton
              :message="`Comprar ${p.name} por ${fmt(p.price_cents)}?`"
              btn-class="btn-primary btn-sm"
              @confirm="buy(p.id)"
            >
              Comprar
            </ConfirmButton>
          </div>
        </div>
      </div>
    </div>
  </PortalLayout>
</template>

<script setup>
import { router, usePage } from "@inertiajs/vue3";
import PortalLayout from "@/components/Portal/PortalLayout.vue";
import ConfirmButton from "@/components/Shared/ConfirmButton.vue";

const props = defineProps({
  products: Array,
  portal_config: Object,
  branding: Object,
});

const page = usePage();
const portalConfig = props.portal_config;

const buy = (productId) =>
  router.post(`/portal/${page.props.portal_token}/products`, {
    product_id: productId,
  });

const fmt = (v) =>
  new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(
    (v || 0) / 100,
  );
const fmtNum = (v) => new Intl.NumberFormat("pt-BR").format(v || 0);
</script>

<template>
  <PortalLayout
    :customer="$page.props.customer"
    :branding="branding"
    :portal-config="portalConfig"
  >
    <h1 class="text-xl font-semibold text-gray-900 mb-6">Comprar pacotes</h1>

    <div v-if="buyError" class="mb-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
      {{ buyError }}
    </div>

    <div v-if="!products.length" class="card">
      <div class="card-body text-center py-12 text-gray-400">
        Nenhum pacote disponível no momento.
      </div>
    </div>

    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <div v-for="p in products" :key="p.id" class="card">
        <div class="card-body space-y-3">
          <div>
            <div class="flex items-center justify-between gap-2">
              <h3 class="font-semibold text-gray-900">{{ p.name }}</h3>
              <span
                :class="[
                  'text-xs px-2 py-0.5 rounded-full font-medium',
                  p.recurring
                    ? 'bg-blue-50 text-blue-700'
                    : 'bg-gray-100 text-gray-600',
                ]"
              >
                {{ p.recurring ? "Recorrente" : "Avulso" }}
              </span>
            </div>
            <p v-if="p.description" class="text-sm text-gray-500 mt-0.5">
              {{ p.description }}
            </p>
          </div>

          <div
            v-if="p.grants_credit"
            class="bg-gray-50 rounded-lg px-3 py-2 text-sm"
          >
            <span class="text-gray-500">
              {{ fmtNum(p.credit_quantity * qty(p)) }} {{ p.credit_unit }}s
              <template v-if="qty(p) > 1">
                ({{ fmtNum(p.credit_quantity) }} × {{ qty(p) }})
              </template>
            </span>
          </div>

          <div class="flex items-center gap-2">
            <label class="text-sm text-gray-500">Quantidade</label>
            <input
              v-model.number="quantities[p.id]"
              type="number"
              min="1"
              class="w-20 rounded-lg border-gray-300 text-sm focus:ring-brand-500 focus:border-brand-500"
            />
          </div>

          <div class="flex items-center justify-between pt-2">
            <div>
              <span class="text-xl font-bold text-gray-900">
                {{ fmt(totalCents(p)) }}
              </span>
              <p v-if="p.recurring" class="text-xs text-gray-400">
                somado à assinatura
              </p>
            </div>
            <ConfirmButton
              :message="`Comprar ${qty(p)}× ${p.name} por ${fmt(totalCents(p))}?`"
              btn-class="btn-primary btn-sm"
              :disabled="buying === p.id"
              @confirm="buy(p)"
            >
              {{ buying === p.id ? "Processando..." : "Comprar" }}
            </ConfirmButton>
          </div>
        </div>
      </div>
    </div>
  </PortalLayout>
</template>

<script setup>
import { reactive, ref } from "vue";
import { usePage } from "@inertiajs/vue3";
import PortalLayout from "@/components/Portal/PortalLayout.vue";
import ConfirmButton from "@/components/Shared/ConfirmButton.vue";

const props = defineProps({
  products: Array,
  portal_config: Object,
  branding: Object,
});

const page = usePage();
const portalConfig = props.portal_config;

// Quantidade selecionada por produto (default 1)
const quantities = reactive(
  Object.fromEntries((props.products || []).map((p) => [p.id, 1])),
);

const qty = (p) => Math.max(parseInt(quantities[p.id], 10) || 1, 1);

const totalCents = (p) => {
  const q = qty(p);
  if (p.pricing_model === "flat") return (p.price_cents || 0) * q;
  if (p.pricing_model === "volume") {
    const tier = (p.pricing_tiers || []).find(
      (t) => q >= t.from_unit && (t.to_unit == null || q <= t.to_unit),
    );
    return tier ? tier.unit_amount_cents * q : (p.price_cents || 0) * q;
  }
  return (p.price_cents || 0) * q;
};

const buying = ref(null);
const buyError = ref(null);

const buy = async (p) => {
  buying.value = p.id;
  buyError.value = null;
  try {
    const res = await fetch(`/portal/${page.props.portal_token}/products`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
        Accept: "application/json",
      },
      body: JSON.stringify({ product_id: p.id, quantity: qty(p) }),
    });
    const data = await res.json();
    if (!res.ok) {
      buyError.value = data.error || "Erro ao processar a compra.";
      return;
    }
    window.open(data.payment_url, "_blank");
  } catch {
    buyError.value = "Erro ao processar a compra.";
  } finally {
    buying.value = null;
  }
};

const fmt = (v) =>
  new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(
    (v || 0) / 100,
  );
const fmtNum = (v) => new Intl.NumberFormat("pt-BR").format(v || 0);
</script>

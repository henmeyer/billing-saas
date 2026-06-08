<template>
  <AppLayout>
    <div class="page-header">
      <div class="flex items-center gap-3">
        <Link
          :href="`/customers/${customer.id}`"
          class="text-sm text-gray-500 hover:text-gray-700"
        >
          ← {{ customer.name }}
        </Link>
        <h2 class="page-title">
          {{ subscription.id ? "Editar assinatura" : "Nova assinatura" }}
        </h2>
      </div>
    </div>

    <div class="max-w-lg space-y-6">
      <div v-if="errors.length" class="alert-danger">
        <div>
          <p v-for="err in errors" :key="err">{{ err }}</p>
        </div>
      </div>

      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Dados da assinatura</h3>
        </div>
        <div class="card-body space-y-4">
          <div>
            <label class="form-label">Plano</label>
            <select v-model="form.plan_id" class="form-input">
              <option value="">Selecione um plano</option>
              <option v-for="p in plans" :key="p.id" :value="p.id">
                {{ p.name }} ({{ p.billing_cycle === "monthly" ? "mensal" : "anual" }})
              </option>
            </select>
          </div>

          <div>
            <label class="form-label">Gateway de pagamento</label>
            <select v-model="form.gateway" class="form-input" :disabled="!!subscription.id">
              <option value="">Selecione o gateway</option>
              <option v-for="g in gateways" :key="g.id" :value="g.provider">
                {{ g.provider }}
              </option>
            </select>
            <p v-if="subscription.id" class="form-hint">
              Gateway não pode ser alterado após criação.
            </p>
          </div>

          <div v-if="!subscription.id">
            <label class="form-label">
              ID da assinatura no gateway
              <span class="text-gray-400 font-normal">(opcional)</span>
            </label>
            <input
              v-model="form.gateway_subscription_id"
              type="text"
              class="form-input font-mono"
              placeholder="Deixe em branco para gerar automaticamente"
            />
            <p class="form-hint">
              Se o cliente já tem assinatura ativa no gateway, cole o ID aqui.
            </p>
          </div>

          <div v-if="subscription.id">
            <label class="form-label">Status</label>
            <select v-model="form.status" class="form-input">
              <option value="active">Ativo</option>
              <option value="past_due">Inadimplente</option>
              <option value="trialing">Trial</option>
              <option value="cancelled">Cancelado</option>
            </select>
          </div>

          <div>
            <label class="form-label">Moeda da assinatura</label>
            <select
              v-model.number="form.currency_id"
              class="form-input"
              :disabled="!!subscription.id"
            >
              <option v-for="c in currencies" :key="c.id" :value="c.id">
                {{ c.code }} — {{ c.name }} ({{ c.symbol }})
              </option>
            </select>
            <p v-if="subscription.id" class="form-hint">
              Moeda não pode ser alterada após criação.
            </p>
          </div>

          <div v-if="!subscription.id">
            <label class="form-label">Data de início</label>
            <input v-model="form.started_at" type="date" class="form-input" />
          </div>
        </div>
      </div>

      <div v-if="selectedPlan && selectedCurrency" class="card bg-gray-50">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Resumo da cobrança</h3>
        </div>
        <div class="card-body space-y-3 text-sm">
          <div v-if="selectedPlan.pricing_model !== 'flat'" class="flex justify-between">
            <span class="text-gray-500">
              Modelo: <strong>{{ pricingModelLabel }}</strong>
            </span>
            <span class="text-gray-500">
              Métrica: <strong>{{ selectedPlan.pricing_metric_label || '—' }}</strong>
            </span>
          </div>

          <div v-if="selectedPlan.pricing_model !== 'flat'">
            <label class="form-label text-xs">
              Quantidade atual de {{ selectedPlan.pricing_metric_label || 'unidades' }}
            </label>
            <input
              v-model.number="form.initial_quantity"
              type="number" min="0"
              class="form-input w-32"
              placeholder="0"
            />
            <p class="form-hint">Quantidade do cliente no momento da assinatura</p>
          </div>

          <div class="flex justify-between pt-2 border-t border-gray-200">
            <span class="text-gray-600">Valor da primeira cobrança</span>
            <span class="font-semibold text-gray-900 text-base">{{ calculatedPrice }}</span>
          </div>

          <div v-if="selectedPlan.pricing_model === 'volume' && activeTier" class="text-xs text-gray-400">
            Faixa aplicada: {{ activeTier.label }} →
            {{ selectedCurrency.symbol }} {{ (activeTier.unit_amount_cents / 100).toFixed(2) }}/un
          </div>

          <div v-if="!priceAvailable && selectedPlan.pricing_model === 'flat'" class="text-xs text-amber-600">
            ⚠ Este plano não tem preço cadastrado para {{ selectedCurrency.code }}.
          </div>
        </div>
      </div>

      <div class="flex gap-3 justify-end">
        <Link :href="`/customers/${customer.id}`" class="btn-secondary">
          Cancelar
        </Link>

        <ConfirmButton
          v-if="subscription.id"
          message="Cancelar esta assinatura? Esta ação não pode ser desfeita."
          btn-class="btn-danger"
          @confirm="cancelSubscription"
        >
          Cancelar assinatura
        </ConfirmButton>

        <button @click="submit" :disabled="form.processing" class="btn-primary">
          {{
            form.processing
              ? "Salvando..."
              : subscription.id
                ? "Salvar"
                : "Criar assinatura"
          }}
        </button>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { computed } from "vue";
import { Link, useForm, router } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";
import ConfirmButton from "@/components/Shared/ConfirmButton.vue";

const props = defineProps({
  customer: Object,
  subscription: Object,
  plans: Array,
  gateways: Array,
  currencies: { type: Array, default: () => [] },
  default_currency_id: { type: Number, default: null },
  errors: { type: [Array, Object], default: () => [] },
});

const form = useForm({
  plan_id:                 props.subscription.plan_id     || "",
  gateway:                 props.subscription.gateway     || "",
  currency_id:             props.subscription.currency_id || props.default_currency_id || "",
  gateway_subscription_id: props.subscription.gateway_subscription_id || "",
  status:                  props.subscription.status      || "active",
  started_at:              props.subscription.started_at  || new Date().toISOString().split("T")[0],
  initial_quantity:        1,
});

const selectedPlan = computed(() =>
  props.plans.find((p) => p.id === Number(form.plan_id)),
);

const selectedCurrency = computed(() =>
  props.currencies.find((c) => c.id === Number(form.currency_id)),
);

const priceAvailable = computed(() => {
  if (!selectedPlan.value || !selectedCurrency.value) return false;
  return selectedPlan.value.prices?.some((p) => p.currency_id === selectedCurrency.value.id);
});

const pricingModelLabel = computed(() => ({
  flat:     "Fixo",
  per_unit: "Por unidade",
  volume:   "Volume",
}[selectedPlan.value?.pricing_model] || ""));

const activeTier = computed(() => {
  if (selectedPlan.value?.pricing_model !== "volume" || !selectedCurrency.value) return null;
  const qty = form.initial_quantity || 1;
  return selectedPlan.value.pricing_tiers
    ?.filter((t) => t.currency_id === selectedCurrency.value.id)
    ?.find((t) => qty >= t.from_unit && (!t.to_unit || qty <= t.to_unit));
});

const calculatedPrice = computed(() => {
  if (!selectedPlan.value || !selectedCurrency.value) return "—";
  const qty      = form.initial_quantity || 1;
  const symbol   = selectedCurrency.value.symbol;
  const priceMap = selectedPlan.value.prices?.find((p) => p.currency_id === selectedCurrency.value.id);
  const tierMap  = selectedPlan.value.pricing_tiers?.filter((t) => t.currency_id === selectedCurrency.value.id) || [];
  let amount = 0;

  if (selectedPlan.value.pricing_model === "flat") {
    amount = priceMap?.amount_cents || 0;
  } else if (selectedPlan.value.pricing_model === "per_unit") {
    amount = (priceMap?.amount_cents || 0) * qty;
  } else if (selectedPlan.value.pricing_model === "volume") {
    const tier = tierMap.find((t) => qty >= t.from_unit && (!t.to_unit || qty <= t.to_unit));
    amount = tier ? tier.unit_amount_cents * qty : 0;
  }

  return `${symbol} ${(amount / 100).toFixed(2)}`;
});

const submit = () => {
  const base = `/customers/${props.customer.id}/subscriptions`;
  const url = props.subscription.id ? `${base}/${props.subscription.id}` : base;
  const method = props.subscription.id ? "put" : "post";
  form[method](url);
};

const cancelSubscription = () => {
  router.delete(
    `/customers/${props.customer.id}/subscriptions/${props.subscription.id}`,
  );
};

</script>

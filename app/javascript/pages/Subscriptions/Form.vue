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

      <!-- Widget de créditos extras -->
      <div v-if="selectedPlan && creditsWithExtras.length" class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Créditos adicionais</h3>
          <p class="text-xs text-gray-500 mt-0.5">
            O plano inclui a quantidade base. Adicione pacotes extras se necessário.
          </p>
        </div>
        <div class="card-body space-y-4">
          <div
            v-for="credit in creditsWithExtras"
            :key="credit.credit_type_id"
            class="flex items-center gap-4"
          >
            <div class="flex-1">
              <p class="text-sm font-medium text-gray-700">{{ credit.credit_type_label }}</p>
              <p class="text-xs text-gray-400">
                Base inclusa: {{ fmtNum(credit.base_quantity) }} {{ credit.unit }}s/mês
              </p>
            </div>

            <div class="flex items-center gap-2">
              <button
                type="button"
                @click="decrementPackage(credit.credit_type_id)"
                :disabled="(extraPackages[credit.credit_type_id] || 0) <= 0"
                class="w-7 h-7 rounded-full border border-gray-300 flex items-center justify-center
                       text-gray-500 hover:border-brand-500 hover:text-brand-600
                       disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
              >−</button>

              <div class="text-center w-32">
                <p class="text-sm font-semibold text-gray-900">
                  {{ fmtNum(totalQuantity(credit)) }}
                </p>
                <p class="text-xs text-gray-400">{{ credit.unit }}s/mês</p>
              </div>

              <button
                type="button"
                @click="incrementPackage(credit.credit_type_id)"
                class="w-7 h-7 rounded-full border border-gray-300 flex items-center justify-center
                       text-gray-500 hover:border-brand-500 hover:text-brand-600 transition-colors"
              >+</button>

              <div class="text-right w-24">
                <p class="text-xs text-gray-500">
                  + {{ extraPackages[credit.credit_type_id] || 0 }} pacote(s)
                </p>
                <p class="text-xs font-medium text-brand-600">
                  + {{ fmtCents(extraCost(credit)) }}
                </p>
              </div>
            </div>
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

          <div class="flex justify-between">
            <span class="text-gray-600">Plano base</span>
            <span class="font-medium text-gray-900">{{ calculatedPrice }}</span>
          </div>

          <template>
            <div
              v-for="credit in creditsWithExtras"
              :key="credit.credit_type_id"
              v-show="(extraPackages[credit.credit_type_id] || 0) > 0"
              class="flex justify-between"
            >
              <span class="text-gray-500">
                {{ extraPackages[credit.credit_type_id] || 0 }}×
                pacote {{ credit.credit_type_label }}
                ({{ fmtNum(credit.extra_unit_size) }} {{ credit.unit }}s)
              </span>
              <span class="text-gray-700">+ {{ fmtCents(extraCost(credit)) }}</span>
            </div>

            <div v-if="totalExtrasCents > 0" class="flex justify-between pt-2 border-t border-gray-200">
              <span class="font-medium text-gray-900">Total mensal</span>
              <span class="font-semibold text-lg text-gray-900">{{ totalMonthlyFormatted }}</span>
            </div>
          </template>

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
import { computed, reactive } from "vue";
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

const extraPackages = reactive({ ...(props.subscription.extra_packages || {}) });

const selectedPlan = computed(() =>
  props.plans.find((p) => p.id === Number(form.plan_id)),
);

const selectedCurrency = computed(() =>
  props.currencies.find((c) => c.id === Number(form.currency_id)),
);

const creditsWithExtras = computed(() =>
  selectedPlan.value?.credits?.filter((c) => c.allow_extras) || [],
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

const basePriceCents = computed(() => {
  if (!selectedPlan.value || !selectedCurrency.value) return 0;
  const qty      = form.initial_quantity || 1;
  const priceMap = selectedPlan.value.prices?.find((p) => p.currency_id === selectedCurrency.value.id);
  const tierMap  = selectedPlan.value.pricing_tiers?.filter((t) => t.currency_id === selectedCurrency.value.id) || [];

  if (selectedPlan.value.pricing_model === "flat") return priceMap?.amount_cents || 0;
  if (selectedPlan.value.pricing_model === "per_unit") return (priceMap?.amount_cents || 0) * qty;
  if (selectedPlan.value.pricing_model === "volume") {
    const tier = tierMap.find((t) => qty >= t.from_unit && (!t.to_unit || qty <= t.to_unit));
    return tier ? tier.unit_amount_cents * qty : 0;
  }
  return 0;
});

const calculatedPrice = computed(() => {
  if (!selectedPlan.value || !selectedCurrency.value) return "—";
  return `${selectedCurrency.value.symbol} ${(basePriceCents.value / 100).toFixed(2)}`;
});

const incrementPackage = (creditTypeId) => {
  extraPackages[creditTypeId] = (extraPackages[creditTypeId] || 0) + 1;
};

const decrementPackage = (creditTypeId) => {
  if ((extraPackages[creditTypeId] || 0) > 0) extraPackages[creditTypeId]--;
};

const totalQuantity = (credit) => {
  const n = extraPackages[credit.credit_type_id] || 0;
  return credit.base_quantity + n * credit.extra_unit_size;
};

const extraCost = (credit) => {
  const n = extraPackages[credit.credit_type_id] || 0;
  return n * credit.extra_unit_price_cents;
};

const totalExtrasCents = computed(() =>
  creditsWithExtras.value.reduce((sum, c) => sum + extraCost(c), 0),
);

const totalMonthlyFormatted = computed(() => {
  if (!selectedCurrency.value) return "—";
  return `${selectedCurrency.value.symbol} ${((basePriceCents.value + totalExtrasCents.value) / 100).toFixed(2)}`;
});

const fmtCents = (v) =>
  new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(
    (v || 0) / 100,
  );

const fmtNum = (v) => new Intl.NumberFormat("pt-BR").format(v || 0);

const submit = () => {
  const base = `/customers/${props.customer.id}/subscriptions`;
  const url = props.subscription.id ? `${base}/${props.subscription.id}` : base;
  const method = props.subscription.id ? "put" : "post";
  form.transform((data) => ({ ...data, extra_packages: extraPackages }))[method](url);
};

const cancelSubscription = () => {
  router.delete(
    `/customers/${props.customer.id}/subscriptions/${props.subscription.id}`,
  );
};
</script>

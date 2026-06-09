<template>
  <AppLayout>
    <div class="page-header">
      <div class="flex items-center gap-3">
        <Link href="/plans" class="text-sm text-gray-500 hover:text-gray-700"
          >← Planos</Link
        >
        <h2 class="page-title">
          {{ plan.id ? "Editar plano" : "Novo plano" }}
        </h2>
      </div>
    </div>

    <div class="max-w-2xl space-y-6">
      <div v-if="Object.keys(errors).length" class="alert-danger">
        <div>
          <p v-for="(msgs, field) in errors" :key="field">
            {{ msgs.join(", ") }}
          </p>
        </div>
      </div>

      <!-- Informações básicas -->
      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Informações básicas</h3>
        </div>
        <div class="card-body space-y-4">
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="form-label">Nome do plano</label>
              <input
                v-model="form.name"
                type="text"
                class="form-input"
                placeholder="Ex: Starter, Pro, Business"
              />
            </div>
            <div>
              <label class="form-label">Ciclo de cobrança</label>
              <select v-model="form.billing_cycle" class="form-input">
                <option value="monthly">Mensal</option>
                <option value="yearly">Anual</option>
              </select>
            </div>
          </div>

          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="form-label">Dias de trial</label>
              <input
                v-model.number="form.trial_days"
                type="number"
                min="0"
                class="form-input"
              />
              <p class="form-hint">0 = sem trial</p>
            </div>
          </div>

          <div>
            <label class="form-label">Descrição (opcional)</label>
            <textarea
              v-model="form.description"
              rows="2"
              class="form-input"
              placeholder="Descrição exibida para o cliente"
            />
          </div>
        </div>
      </div>

      <!-- Modelo de precificação -->
      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">
            Modelo de precificação
          </h3>
        </div>
        <div class="card-body space-y-4">
          <div class="grid grid-cols-3 gap-3">
            <label
              v-for="model in pricingModels"
              :key="model.value"
              :class="[
                'border rounded-lg p-3 cursor-pointer transition-colors',
                form.pricing_model === model.value
                  ? 'border-brand-500 bg-brand-50'
                  : 'border-gray-200 hover:border-gray-300',
              ]"
            >
              <input
                type="radio"
                :value="model.value"
                v-model="form.pricing_model"
                class="sr-only"
              />
              <p class="text-sm font-medium text-gray-900">{{ model.label }}</p>
              <p class="text-xs text-gray-500 mt-0.5">
                {{ model.description }}
              </p>
            </label>
          </div>

          <!-- Métrica (per_unit e volume) -->
          <template v-if="form.pricing_model !== 'flat'">
            <div>
              <label class="form-label">Métrica de cobrança</label>
              <p class="text-xs text-gray-500 mb-2">
                Qual campo define a quantidade para o cálculo?
              </p>
              <div class="grid grid-cols-2 gap-3">
                <div>
                  <p class="text-xs font-medium text-gray-500 mb-1.5">
                    Licenças
                  </p>
                  <label
                    v-for="lt in licenseTypes"
                    :key="'lt-' + lt.id"
                    class="flex items-center gap-2 text-sm text-gray-700 cursor-pointer mb-1"
                  >
                    <input
                      type="radio"
                      :value="lt.id"
                      v-model="form.pricing_license_type_id"
                      @change="form.pricing_credit_type_id = null"
                      class="border-gray-300 text-brand-600 focus:ring-brand-500"
                    />
                    {{ lt.label }}
                    <span class="text-xs text-gray-400 font-mono">{{
                      lt.key
                    }}</span>
                  </label>
                </div>
                <div>
                  <p class="text-xs font-medium text-gray-500 mb-1.5">
                    Créditos
                  </p>
                  <label
                    v-for="ct in creditTypes"
                    :key="'ct-' + ct.id"
                    class="flex items-center gap-2 text-sm text-gray-700 cursor-pointer mb-1"
                  >
                    <input
                      type="radio"
                      :value="ct.id"
                      v-model="form.pricing_credit_type_id"
                      @change="form.pricing_license_type_id = null"
                      class="border-gray-300 text-brand-600 focus:ring-brand-500"
                    />
                    {{ ct.label }}
                    <span class="text-xs text-gray-400 font-mono">{{
                      ct.key
                    }}</span>
                  </label>
                </div>
              </div>
            </div>
          </template>
        </div>
      </div>

      <!-- Preços por moeda (flat e per_unit) -->
      <div
        v-if="currencies.length && form.pricing_model !== 'volume'"
        class="card"
      >
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">
            {{
              form.pricing_model === "per_unit" ? "Preço por unidade" : "Preços"
            }}
          </h3>
          <p class="text-xs text-gray-500 mt-0.5">
            <template v-if="form.pricing_model === 'per_unit'">
              Preço por {{ pricingMetricLabel || "unidade" }} em cada moeda
            </template>
            <template v-else> Defina o preço para cada moeda aceita </template>
          </p>
        </div>
        <div class="card-body space-y-4">
          <div
            v-for="cur in currencies"
            :key="cur.id"
            class="flex items-start gap-3"
          >
            <div class="w-16 pt-2 text-center flex-shrink-0">
              <span class="font-mono text-sm font-semibold text-gray-700">{{
                cur.code
              }}</span>
              <p class="text-xs text-gray-400">{{ cur.symbol }}</p>
            </div>
            <div class="flex-1">
              <div class="relative">
                <span
                  class="absolute left-3 top-1/2 -translate-y-1/2 text-sm text-gray-400 pointer-events-none"
                >
                  {{ cur.symbol }}
                </span>
                <input
                  v-model.number="prices[cur.id]"
                  type="number"
                  min="0"
                  step="0.01"
                  class="form-input pl-8"
                  :placeholder="
                    cur.default ? 'Obrigatório' : 'Deixe vazio para não aceitar'
                  "
                />
              </div>
              <p v-if="prices[cur.id] > 0" class="form-hint mt-1">
                {{ fmtPrice(prices[cur.id], cur) }}/{{
                  form.pricing_model === "per_unit"
                    ? pricingMetricLabel || "unidade"
                    : form.billing_cycle === "monthly"
                      ? "mês"
                      : "ano"
                }}
              </p>
            </div>
            <div class="pt-2">
              <Badge v-if="cur.default" variant="blue">Padrão</Badge>
            </div>
          </div>
        </div>
      </div>

      <!-- Faixas de volume -->
      <div
        v-if="form.pricing_model === 'volume' && currencies.length"
        class="card"
      >
        <div class="card-header">
          <div class="flex items-center justify-between">
            <h3 class="text-sm font-medium text-gray-900">Faixas de volume</h3>
            <button type="button" @click="addTier" class="btn-secondary btn-sm">
              + Faixa
            </button>
          </div>
          <p class="text-xs text-gray-500 mt-0.5">
            Preço da faixa vale para todas as unidades. Última sem "até" =
            ilimitado.
          </p>
        </div>
        <div class="card-body space-y-4">
          <!-- Tabs de moeda -->
          <div class="flex gap-2">
            <button
              v-for="c in currencies"
              :key="c.id"
              type="button"
              @click="activeCurrencyId = c.id"
              :class="[
                'px-3 py-1.5 text-xs rounded-lg font-medium transition-colors',
                activeCurrencyId === c.id
                  ? 'bg-brand-600 text-white'
                  : 'bg-gray-100 text-gray-600 hover:bg-gray-200',
              ]"
            >
              {{ c.code }}
            </button>
          </div>

          <div class="space-y-2">
            <div
              v-for="(tier, index) in tiersForActiveCurrency"
              :key="index"
              class="flex items-center gap-2"
            >
              <span class="text-xs text-gray-500 w-4">{{ index + 1 }}</span>
              <div class="flex items-center gap-1 flex-1">
                <input
                  v-model.number="tier.from_unit"
                  type="number"
                  min="1"
                  class="w-20 rounded-lg border-gray-300 text-sm focus:ring-brand-500"
                  placeholder="De"
                />
                <span class="text-xs text-gray-400">até</span>
                <input
                  v-model.number="tier.to_unit"
                  type="number"
                  min="1"
                  class="w-20 rounded-lg border-gray-300 text-sm focus:ring-brand-500"
                  placeholder="∞"
                />
                <span class="text-xs text-gray-400 mx-1">{{
                  pricingMetricLabel
                }}</span>
              </div>
              <div class="relative w-36">
                <span
                  class="absolute left-2 top-1/2 -translate-y-1/2 text-xs text-gray-400"
                >
                  {{ activeCurrency?.symbol }}
                </span>
                <input
                  v-model.number="tier.unit_amount_cents"
                  type="number"
                  min="0"
                  step="1"
                  class="w-full pl-6 rounded-lg border-gray-300 text-sm focus:ring-brand-500"
                  placeholder="Preço/un"
                />
              </div>
              <span class="text-xs text-gray-400">/ un</span>
              <button
                type="button"
                @click="removeTier(index)"
                class="text-gray-300 hover:text-red-400 transition-colors text-lg leading-none"
              >
                ×
              </button>
            </div>
            <div
              v-if="!tiersForActiveCurrency.length"
              class="text-sm text-gray-400 text-center py-3"
            >
              Nenhuma faixa para {{ activeCurrency?.code }}.
            </div>
          </div>
        </div>
      </div>

      <!-- Simulador -->
      <div v-if="form.pricing_model !== 'flat'" class="card bg-gray-50">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Simulador de preço</h3>
        </div>
        <div class="card-body">
          <div class="flex items-center gap-3 mb-3">
            <label class="text-sm text-gray-600">
              Simular com {{ pricingMetricLabel || "unidades" }}:
            </label>
            <input
              v-model.number="simulatedQty"
              type="number"
              min="1"
              class="w-24 rounded-lg border-gray-300 text-sm focus:ring-brand-500"
            />
          </div>
          <div class="space-y-1">
            <div
              v-for="c in currencies"
              :key="c.id"
              class="flex justify-between text-sm"
            >
              <span class="text-gray-600">{{ c.code }}</span>
              <span class="font-medium text-gray-900"
                >{{ c.symbol }} {{ simulatePrice(c) }}</span
              >
            </div>
          </div>
        </div>
      </div>

      <!-- Integrações cobertas -->
      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">
            Integrações cobertas
          </h3>
          <p class="text-xs text-gray-500 mt-0.5">
            Este plano vale para quais integrações
          </p>
        </div>
        <div class="card-body">
          <div v-if="integrations.length" class="space-y-2">
            <label
              v-for="integ in integrations"
              :key="integ.id"
              class="flex items-center gap-2 text-sm text-gray-700 cursor-pointer"
            >
              <input
                type="checkbox"
                :value="integ.id"
                v-model="form.integration_ids"
                class="rounded border-gray-300 text-brand-600 focus:ring-brand-500"
              />
              <span class="font-medium">{{ integ.name }}</span>
              <span class="text-gray-400 font-mono text-xs truncate max-w-xs">{{
                integ.url
              }}</span>
            </label>
          </div>
          <p v-else class="text-sm text-gray-400">
            Nenhuma integração cadastrada ainda.
            <a href="/integrations/new" class="text-brand-600 hover:underline"
              >Criar integração</a
            >
          </p>
        </div>
      </div>

      <!-- Licenças -->
      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Licenças incluídas</h3>
          <p class="text-xs text-gray-500 mt-0.5">0 = ilimitado</p>
        </div>
        <div class="card-body space-y-3">
          <template v-if="licenseTypes.length">
            <div
              v-for="lt in licenseTypes"
              :key="lt.id"
              class="flex items-center gap-4"
            >
              <div class="flex-1">
                <p class="text-sm font-medium text-gray-700">{{ lt.label }}</p>
                <p class="text-xs text-gray-400">{{ lt.key }}</p>
              </div>
              <div class="flex items-center gap-2">
                <input
                  v-model.number="licenses[lt.id]"
                  type="number"
                  min="0"
                  class="w-24 rounded-lg border-gray-300 text-sm focus:ring-brand-500 focus:border-brand-500"
                />
                <span class="text-xs text-gray-400 w-20">{{ lt.unit }}(s)</span>
                <span
                  v-if="licenses[lt.id] === 0"
                  class="text-xs text-gray-400 italic"
                  >ilimitado</span
                >
              </div>
            </div>
          </template>
          <p v-else class="text-sm text-gray-400">
            Nenhum tipo de licença configurado.
          </p>
        </div>
      </div>

      <!-- Créditos -->
      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Créditos por ciclo</h3>
        </div>
        <div class="card-body space-y-4">
          <template v-if="creditTypes.length">
            <div
              v-for="ct in creditTypes"
              :key="ct.id"
              class="border border-gray-100 rounded-lg p-4 space-y-3"
            >
              <!-- Cabeçalho -->
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-sm font-medium text-gray-700">{{ ct.label }}</p>
                  <p class="text-xs text-gray-400 font-mono">{{ ct.key }}</p>
                </div>
              </div>

              <!-- Quantidade base + rollover -->
              <div class="grid grid-cols-2 gap-3">
                <div>
                  <label class="text-xs text-gray-500 mb-1 block">Quantidade base incluída</label>
                  <input
                    v-model.number="credits[ct.id].quantity"
                    type="number" min="0"
                    class="form-input text-sm"
                    :placeholder="`Ex: 2000 ${ct.unit}s/mês`"
                  />
                </div>
                <div class="flex items-center gap-2 pt-5">
                  <label class="flex items-center gap-2 text-sm text-gray-600 cursor-pointer">
                    <input
                      v-model="credits[ct.id].rollover"
                      type="checkbox"
                      class="rounded border-gray-300 text-brand-600"
                    />
                    Acumula saldo não usado
                  </label>
                </div>
              </div>

              <!-- Extras pagos -->
              <div class="border-t border-gray-100 pt-3">
                <label class="flex items-center gap-2 text-sm text-gray-700 cursor-pointer mb-3">
                  <input
                    v-model="credits[ct.id].allow_extras"
                    type="checkbox"
                    class="rounded border-gray-300 text-brand-600"
                  />
                  <span class="font-medium">Permitir compra de extras</span>
                </label>

                <div v-if="credits[ct.id].allow_extras" class="grid grid-cols-2 gap-3 pl-6">
                  <div>
                    <label class="text-xs text-gray-500 mb-1 block">Tamanho do pacote extra</label>
                    <div class="relative">
                      <input
                        v-model.number="credits[ct.id].extra_unit_size"
                        type="number" min="1"
                        class="form-input text-sm"
                        placeholder="1000"
                      />
                      <span class="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-gray-400">
                        {{ ct.unit }}s
                      </span>
                    </div>
                  </div>
                  <div>
                    <label class="text-xs text-gray-500 mb-1 block">Preço por pacote (centavos)</label>
                    <div class="relative">
                      <span class="absolute left-3 top-1/2 -translate-y-1/2 text-xs text-gray-400">R$</span>
                      <input
                        v-model.number="credits[ct.id].extra_unit_price_cents"
                        type="number" min="0"
                        class="form-input text-sm pl-8"
                        placeholder="8990"
                      />
                    </div>
                    <p class="text-xs text-gray-400 mt-0.5">
                      = {{ fmtCents(credits[ct.id].extra_unit_price_cents) }}
                      por {{ fmtNum(credits[ct.id].extra_unit_size) }} {{ ct.unit }}s
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </template>
          <p v-else class="text-sm text-gray-400">
            Nenhum tipo de crédito configurado.
          </p>
        </div>
      </div>

      <!-- Features -->
      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Features</h3>
          <p class="text-xs text-gray-500 mt-0.5">
            Funcionalidades habilitadas neste plano
          </p>
        </div>
        <div class="card-body space-y-2">
          <div v-if="featureTypes.length">
            <label
              v-for="ft in featureTypes"
              :key="ft.id"
              class="flex items-center justify-between py-2 border-b border-gray-100 last:border-0 cursor-pointer"
            >
              <div>
                <p class="text-sm font-medium text-gray-700">{{ ft.label }}</p>
                <p class="text-xs text-gray-400 font-mono">{{ ft.key }}</p>
              </div>
              <input
                type="checkbox"
                :checked="features[ft.id]"
                @change="features[ft.id] = $event.target.checked"
                class="rounded border-gray-300 text-brand-600 focus:ring-brand-500 w-4 h-4"
              />
            </label>
          </div>
          <p v-else class="text-sm text-gray-400">
            Nenhuma feature configurada ainda.
          </p>
        </div>
      </div>

      <!-- Ações -->
      <div class="flex gap-3 justify-end">
        <Link href="/plans" class="btn-secondary">Cancelar</Link>
        <button @click="submit" :disabled="form.processing" class="btn-primary">
          {{
            form.processing
              ? "Salvando..."
              : plan.id
                ? "Salvar alterações"
                : "Criar plano"
          }}
        </button>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { ref, reactive, computed } from "vue";
import { Link, useForm } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";
import Badge from "@/components/Shared/Badge.vue";

const props = defineProps({
  plan: Object,
  license_types: Array,
  credit_types: Array,
  feature_types: Array,
  integrations: Array,
  currencies: Array,
  errors: Object,
});

const licenseTypes = props.license_types || [];
const creditTypes = props.credit_types || [];
const featureTypes = props.feature_types || [];
const integrations = props.integrations || [];
const currencies = props.currencies || [];

const pricingModels = [
  {
    value: "flat",
    label: "Fixo",
    description: "Preço fixo independente do uso",
  },
  {
    value: "per_unit",
    label: "Por unidade",
    description: "Preço × quantidade da métrica",
  },
  {
    value: "volume",
    label: "Volume",
    description: "Faixas com preço por unidade",
  },
];

const form = useForm({
  name: props.plan.name || "",
  description: props.plan.description || "",
  billing_cycle: props.plan.billing_cycle || "monthly",
  trial_days: props.plan.trial_days || 0,
  integration_ids: props.plan.integration_ids || [],
  pricing_model: props.plan.pricing_model || "flat",
  pricing_license_type_id: props.plan.pricing_license_type_id || null,
  pricing_credit_type_id: props.plan.pricing_credit_type_id || null,
});

const licenses = reactive(
  Object.fromEntries(
    licenseTypes.map((lt) => {
      const existing = props.plan.licenses?.find(
        (l) => l.license_type_id === lt.id,
      );
      return [lt.id, existing?.quantity ?? 0];
    }),
  ),
);

const credits = reactive(
  Object.fromEntries(
    creditTypes.map((ct) => {
      const existing = props.plan.credits?.find(
        (c) => c.credit_type_id === ct.id,
      );
      return [
        ct.id,
        {
          quantity:               existing?.quantity               ?? 0,
          rollover:               existing?.rollover               ?? false,
          allow_extras:           existing?.allow_extras           ?? false,
          extra_unit_size:        existing?.extra_unit_size        ?? 1000,
          extra_unit_price_cents: existing?.extra_unit_price_cents ?? 0,
        },
      ];
    }),
  ),
);

const features = reactive(
  Object.fromEntries(
    featureTypes.map((ft) => {
      const existing = props.plan.features?.find(
        (f) => f.feature_type_id === ft.id,
      );
      return [ft.id, existing?.enabled ?? false];
    }),
  ),
);

// Preços por moeda (flat = preço fixo, per_unit = preço unitário). Armazenados em unidade base (decimais).
const prices = reactive(
  Object.fromEntries(
    currencies.map((cur) => {
      const existing = props.plan.prices?.find((p) => p.currency_id === cur.id);
      return [cur.id, existing ? existing.amount_cents / 100 : null];
    }),
  ),
);

// Faixas de volume por moeda (unit_amount_cents em centavos)
const tiers = reactive(
  Object.fromEntries(
    currencies.map((c) => {
      const existing =
        props.plan.pricing_tiers?.filter((t) => t.currency_id === c.id) || [];
      return [c.id, existing.map((t) => ({ ...t }))];
    }),
  ),
);

const activeCurrencyId = ref(currencies[0]?.id);
const activeCurrency = computed(() =>
  currencies.find((c) => c.id === activeCurrencyId.value),
);
const tiersForActiveCurrency = computed(
  () => tiers[activeCurrencyId.value] || [],
);

const addTier = () => {
  const curr = tiers[activeCurrencyId.value] || [];
  const last = curr[curr.length - 1];
  tiers[activeCurrencyId.value] = [
    ...curr,
    {
      currency_id: activeCurrencyId.value,
      from_unit: last ? (last.to_unit || 0) + 1 : 1,
      to_unit: null,
      unit_amount_cents: 0,
      position: curr.length,
    },
  ];
};

const removeTier = (index) => {
  tiers[activeCurrencyId.value].splice(index, 1);
};

const pricingMetricLabel = computed(() => {
  if (form.pricing_license_type_id)
    return licenseTypes.find((lt) => lt.id === form.pricing_license_type_id)
      ?.label;
  if (form.pricing_credit_type_id)
    return creditTypes.find((ct) => ct.id === form.pricing_credit_type_id)
      ?.label;
  return null;
});

const simulatedQty = ref(5);

const simulatePrice = (currency) => {
  const qty = simulatedQty.value || 1;
  if (form.pricing_model === "per_unit") {
    return (((prices[currency.id] || 0) * 100 * qty) / 100).toFixed(2);
  }
  if (form.pricing_model === "volume") {
    const currTiers = tiers[currency.id] || [];
    const tier = currTiers.find(
      (t) => qty >= t.from_unit && (!t.to_unit || qty <= t.to_unit),
    );
    if (!tier) return "—";
    return (tier.unit_amount_cents * qty).toFixed(2);
  }
  return (prices[currency.id] || 0).toFixed(2);
};

const fmtPrice = (value) => {
  if (!value) return "";
  return new Intl.NumberFormat("pt-BR", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(value);
};

const fmtCents = (v) =>
  new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(
    (v || 0) / 100,
  );

const fmtNum = (v) => new Intl.NumberFormat("pt-BR").format(v || 0);

const submit = () => {
  const url = props.plan.id ? `/plans/${props.plan.id}` : "/plans";
  const method = props.plan.id ? "put" : "post";

  const pricesToCents = Object.fromEntries(
    Object.entries(prices).map(([id, val]) => [
      id,
      val != null ? Math.round(val * 100) : null,
    ]),
  );

  const allTiers = Object.entries(tiers).flatMap(([currencyId, currTiers]) =>
    currTiers.map((t, i) => ({
      ...t,
      currency_id: parseInt(currencyId),
      position: i,
    })),
  );

  form
    .transform((data) => ({
      ...data,
      licenses,
      credits,
      features,
      prices: pricesToCents,
      pricing_tiers: allTiers,
    }))
    [method](url);
};
</script>

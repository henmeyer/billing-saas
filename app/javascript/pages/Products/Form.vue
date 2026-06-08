<template>
  <AppLayout>
    <div class="page-header">
      <div class="flex items-center gap-3">
        <Link href="/products" class="text-sm text-gray-500 hover:text-gray-700">
          ← Produtos
        </Link>
        <h2 class="page-title">
          {{ product.id ? "Editar produto" : "Novo produto" }}
        </h2>
      </div>
    </div>

    <div class="max-w-lg space-y-6">
      <div v-if="Object.keys(errors).length" class="alert-danger">
        <div>
          <p v-for="(msgs, field) in errors" :key="field">
            {{ msgs.join(", ") }}
          </p>
        </div>
      </div>

      <!-- Informações -->
      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Informações</h3>
        </div>
        <div class="card-body space-y-4">
          <div>
            <label class="form-label">Nome</label>
            <input
              v-model="form.name"
              type="text"
              class="form-input"
              placeholder="Ex: Pacote 1000 Coins"
            />
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

          <div>
            <label class="form-label">Tipo</label>
            <select v-model="form.product_type" class="form-input">
              <option value="credit_pack">Pacote de créditos</option>
              <option value="one_time">Cobrança avulsa</option>
            </select>
          </div>

          <template v-if="form.product_type === 'credit_pack'">
            <div>
              <label class="form-label">Tipo de crédito</label>
              <select v-model.number="form.credit_type_id" class="form-input">
                <option value="">Selecione</option>
                <option v-for="ct in creditTypes" :key="ct.id" :value="ct.id">
                  {{ ct.label }} ({{ ct.key }})
                </option>
              </select>
            </div>

            <div>
              <label class="form-label">Quantidade de créditos</label>
              <input
                v-model.number="form.credit_quantity"
                type="number"
                min="1"
                class="form-input"
              />
              <p v-if="selectedCreditType" class="form-hint">
                {{ fmtNum(form.credit_quantity) }} {{ selectedCreditType.unit }}s
              </p>
            </div>
          </template>
        </div>
      </div>

      <!-- Preços por moeda -->
      <div v-if="currencies.length" class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Preços</h3>
          <p class="text-xs text-gray-500 mt-0.5">
            Defina o preço para cada moeda aceita.
          </p>
        </div>
        <div class="card-body space-y-4">
          <div v-for="cur in currencies" :key="cur.id" class="flex items-start gap-3">
            <div class="w-16 pt-2 text-center flex-shrink-0">
              <span class="font-mono text-sm font-semibold text-gray-700">{{ cur.code }}</span>
              <p class="text-xs text-gray-400">{{ cur.symbol }}</p>
            </div>
            <div class="flex-1">
              <div class="relative">
                <span class="absolute left-3 top-1/2 -translate-y-1/2 text-sm text-gray-400 pointer-events-none">
                  {{ cur.symbol }}
                </span>
                <input
                  v-model.number="prices[cur.id]"
                  type="number"
                  min="0"
                  step="0.01"
                  class="form-input pl-8"
                  placeholder="0,00"
                />
              </div>
              <p v-if="prices[cur.id] > 0" class="form-hint mt-1">
                {{ cur.symbol }} {{ fmtDecimal(prices[cur.id]) }}
              </p>
            </div>
          </div>
        </div>
      </div>

      <div class="flex gap-3 justify-end">
        <Link href="/products" class="btn-secondary">Cancelar</Link>
        <button @click="submit" :disabled="form.processing" class="btn-primary">
          {{ form.processing ? "Salvando..." : product.id ? "Salvar" : "Criar produto" }}
        </button>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { computed, reactive } from "vue";
import { Link, useForm } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";

const props = defineProps({
  product:      Object,
  credit_types: Array,
  currencies:   { type: Array, default: () => [] },
  errors:       { type: Object, default: () => ({}) },
});

const creditTypes = props.credit_types || [];
const currencies  = props.currencies   || [];

const form = useForm({
  name:            props.product.name            || "",
  description:     props.product.description     || "",
  product_type:    props.product.product_type    || "credit_pack",
  credit_type_id:  props.product.credit_type_id  || "",
  credit_quantity: props.product.credit_quantity || 0,
});

// Armazena em reais (decimais); converte para centavos no submit
const prices = reactive(
  Object.fromEntries(
    currencies.map((cur) => {
      const existing = props.product.prices?.find((p) => p.currency_id === cur.id);
      return [cur.id, existing ? existing.amount_cents / 100 : null];
    }),
  ),
);

const selectedCreditType = computed(() =>
  creditTypes.find((ct) => ct.id === Number(form.credit_type_id)),
);

const submit = () => {
  const url    = props.product.id ? `/products/${props.product.id}` : "/products";
  const method = props.product.id ? "put" : "post";

  const pricesToCents = Object.fromEntries(
    Object.entries(prices).map(([id, val]) => [id, val != null ? Math.round(val * 100) : null]),
  );

  form.transform((data) => ({ ...data, prices: pricesToCents }))[method](url);
};

const fmtDecimal = (val) =>
  new Intl.NumberFormat("pt-BR", { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(val || 0);

const fmtNum = (val) => new Intl.NumberFormat("pt-BR").format(val || 0);
</script>

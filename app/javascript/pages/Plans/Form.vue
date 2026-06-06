<template>
  <AppLayout>
    <div class="page-header">
      <div class="flex items-center gap-3">
        <Link href="/plans" class="text-sm text-gray-500 hover:text-gray-700">← Planos</Link>
        <h2 class="page-title">{{ plan.id ? "Editar plano" : "Novo plano" }}</h2>
      </div>
    </div>

    <div class="max-w-2xl space-y-6">
      <!-- Erros -->
      <div v-if="Object.keys(errors).length" class="alert-danger">
        <div>
          <p v-for="(msgs, field) in errors" :key="field">{{ msgs.join(", ") }}</p>
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
              <label class="form-label">Preço (em centavos)</label>
              <input
                v-model.number="form.price_cents"
                type="number"
                min="0"
                class="form-input"
                placeholder="Ex: 19700 = R$ 197,00"
              />
              <p class="form-hint">Valor: {{ fmtCents(form.price_cents) }}</p>
            </div>
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

      <!-- Integrações cobertas -->
      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Integrações cobertas</h3>
          <p class="text-xs text-gray-500 mt-0.5">Este plano vale para quais integrações</p>
        </div>
        <div class="card-body">
          <div v-if="integrations.length" class="space-y-2">
            <label
              v-for="i in integrations"
              :key="i.id"
              class="flex items-center gap-2 text-sm text-gray-700 cursor-pointer"
            >
              <input
                type="checkbox"
                :value="i.id"
                v-model="form.integration_ids"
                class="rounded border-gray-300 text-brand-600 focus:ring-brand-500"
              />
              <span class="font-medium">{{ i.name }}</span>
              <span class="text-gray-400 font-mono text-xs truncate max-w-xs">{{ i.url }}</span>
            </label>
          </div>
          <p v-else class="text-sm text-gray-400">
            Nenhuma integração cadastrada ainda.
            <a href="/integrations/new" class="text-brand-600 hover:underline">Criar integração</a>
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
                <span v-if="licenses[lt.id] === 0" class="text-xs text-gray-400 italic">ilimitado</span>
              </div>
            </div>
          </template>
          <p v-else class="text-sm text-gray-400">Nenhum tipo de licença configurado.</p>
        </div>
      </div>

      <!-- Créditos -->
      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Créditos por ciclo</h3>
        </div>
        <div class="card-body space-y-3">
          <template v-if="creditTypes.length">
            <div
              v-for="ct in creditTypes"
              :key="ct.id"
              class="flex items-center gap-4"
            >
              <div class="flex-1">
                <p class="text-sm font-medium text-gray-700">{{ ct.label }}</p>
                <p class="text-xs text-gray-400">{{ ct.key }}</p>
              </div>
              <div class="flex items-center gap-2">
                <input
                  v-model.number="credits[ct.id].quantity"
                  type="number"
                  min="0"
                  class="w-28 rounded-lg border-gray-300 text-sm focus:ring-brand-500 focus:border-brand-500"
                />
                <span class="text-xs text-gray-400 w-16">{{ ct.unit }}(s)</span>
                <label class="flex items-center gap-1.5 text-xs text-gray-500 cursor-pointer">
                  <input
                    v-model="credits[ct.id].rollover"
                    type="checkbox"
                    class="rounded border-gray-300 text-brand-600"
                  />
                  Acumula
                </label>
              </div>
            </div>
          </template>
          <p v-else class="text-sm text-gray-400">Nenhum tipo de crédito configurado.</p>
        </div>
      </div>

      <!-- Ações -->
      <div class="flex gap-3 justify-end">
        <Link href="/plans" class="btn-secondary">Cancelar</Link>
        <button @click="submit" :disabled="form.processing" class="btn-primary">
          {{ form.processing ? "Salvando..." : plan.id ? "Salvar alterações" : "Criar plano" }}
        </button>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { reactive } from "vue";
import { Link, useForm } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";

const props = defineProps({
  plan: Object,
  license_types: Array,
  credit_types: Array,
  integrations: Array,
  errors: Object,
});

const licenseTypes = props.license_types || [];
const creditTypes = props.credit_types || [];
const integrations = props.integrations || [];

const form = useForm({
  name: props.plan.name || "",
  description: props.plan.description || "",
  price_cents: props.plan.price_cents || 0,
  billing_cycle: props.plan.billing_cycle || "monthly",
  trial_days: props.plan.trial_days || 0,
  integration_ids: props.plan.integration_ids || [],
});

const licenses = reactive(
  Object.fromEntries(
    licenseTypes.map((lt) => {
      const existing = props.plan.licenses?.find((l) => l.license_type_id === lt.id);
      return [lt.id, existing?.quantity ?? 0];
    }),
  ),
);

const credits = reactive(
  Object.fromEntries(
    creditTypes.map((ct) => {
      const existing = props.plan.credits?.find((c) => c.credit_type_id === ct.id);
      return [ct.id, { quantity: existing?.quantity ?? 0, rollover: existing?.rollover ?? false }];
    }),
  ),
);

const submit = () => {
  const url = props.plan.id ? `/plans/${props.plan.id}` : "/plans";
  const method = props.plan.id ? "put" : "post";

  form.transform((data) => ({ ...data, licenses, credits }))[method](url);
};

const fmtCents = (cents) =>
  new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(
    (cents || 0) / 100,
  );
</script>

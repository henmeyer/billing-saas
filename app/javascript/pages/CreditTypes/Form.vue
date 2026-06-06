<template>
  <AppLayout>
    <div class="page-header">
      <div class="flex items-center gap-3">
        <Link href="/credit_types" class="text-sm text-gray-500 hover:text-gray-700">
          ← Tipos de crédito
        </Link>
        <h2 class="page-title">
          {{ creditType.id ? "Editar tipo de crédito" : "Novo tipo de crédito" }}
        </h2>
      </div>
    </div>

    <div class="max-w-lg space-y-6">
      <div v-if="Object.keys(errors).length" class="alert-danger">
        <p v-for="(msgs, field) in errors" :key="field">{{ msgs.join(", ") }}</p>
      </div>

      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Informações</h3>
        </div>
        <div class="card-body space-y-4">
          <div>
            <label class="form-label">Chave <span class="text-gray-400 font-normal">(identificador único)</span></label>
            <input
              v-model="form.key"
              type="text"
              class="form-input font-mono"
              placeholder="ex: coins"
              :readonly="!!creditType.id"
            />
            <p class="form-hint">Usado na API. Não pode ser alterado após a criação.</p>
          </div>
          <div>
            <label class="form-label">Label</label>
            <input
              v-model="form.label"
              type="text"
              class="form-input"
              placeholder="ex: Coins"
            />
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="form-label">Unidade</label>
              <input
                v-model="form.unit"
                type="text"
                class="form-input"
                placeholder="ex: coin"
              />
              <p class="form-hint">Singular. Ex: coin, token, mensagem</p>
            </div>
            <div>
              <label class="form-label">Reset</label>
              <select v-model="form.reset_cycle" class="form-input">
                <option value="billing_cycle">Por ciclo de cobrança</option>
                <option value="monthly">Mensal fixo</option>
                <option value="never">Nunca (acumula)</option>
              </select>
            </div>
          </div>
        </div>
      </div>

      <div class="flex gap-3 justify-end">
        <Link href="/credit_types" class="btn-secondary">Cancelar</Link>
        <button @click="submit" :disabled="form.processing" class="btn-primary">
          {{ form.processing ? "Salvando..." : creditType.id ? "Salvar" : "Criar" }}
        </button>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { Link, useForm } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";

const props = defineProps({
  credit_type: Object,
  errors: { type: Object, default: () => ({}) },
});

const creditType = props.credit_type || {};

const form = useForm({
  key:         creditType.key         || "",
  label:       creditType.label       || "",
  unit:        creditType.unit        || "",
  reset_cycle: creditType.reset_cycle || "billing_cycle",
});

const submit = () => {
  const url    = creditType.id ? `/credit_types/${creditType.id}` : "/credit_types";
  const method = creditType.id ? "put" : "post";
  form[method](url);
};
</script>

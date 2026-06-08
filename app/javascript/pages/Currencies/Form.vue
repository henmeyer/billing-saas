<template>
  <AppLayout>
    <div class="page-header">
      <div class="flex items-center gap-3">
        <Link href="/currencies" class="text-sm text-gray-500 hover:text-gray-700">
          ← Moedas
        </Link>
        <h2 class="page-title">
          {{ currency.id ? "Editar moeda" : "Nova moeda" }}
        </h2>
      </div>
    </div>

    <div class="max-w-md space-y-6">
      <div v-if="Object.keys(errors).length" class="alert-danger">
        <div>
          <p v-for="(msgs, field) in errors" :key="field">
            {{ msgs.join(", ") }}
          </p>
        </div>
      </div>

      <div class="card">
        <div class="card-body space-y-4">
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="form-label">Código</label>
              <input
                v-model="form.code"
                type="text"
                class="form-input font-mono uppercase"
                placeholder="BRL"
                maxlength="3"
                :readonly="!!currency.id"
              />
              <p class="form-hint">Ex: BRL, USD, EUR</p>
            </div>
            <div>
              <label class="form-label">Símbolo</label>
              <input
                v-model="form.symbol"
                type="text"
                class="form-input"
                placeholder="R$"
                maxlength="4"
              />
            </div>
          </div>

          <div>
            <label class="form-label">Nome</label>
            <input
              v-model="form.name"
              type="text"
              class="form-input"
              placeholder="Real Brasileiro"
            />
          </div>

          <div class="flex items-center gap-3 pt-2">
            <label class="flex items-center gap-2 text-sm text-gray-700 cursor-pointer">
              <input
                v-model="form.default"
                type="checkbox"
                class="rounded border-gray-300 text-brand-600 focus:ring-brand-500"
              />
              <span class="font-medium">Moeda padrão da conta</span>
            </label>
          </div>
          <p v-if="form.default" class="text-xs text-amber-600">
            ⚠ Definir como padrão remove o padrão da moeda atual.
          </p>
        </div>
      </div>

      <div class="flex gap-3 justify-end">
        <Link href="/currencies" class="btn-secondary">Cancelar</Link>
        <button @click="submit" :disabled="form.processing" class="btn-primary">
          {{ form.processing ? "Salvando..." : currency.id ? "Salvar" : "Criar moeda" }}
        </button>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { Link, useForm } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";

const props = defineProps({
  currency: Object,
  errors: { type: Object, default: () => ({}) },
});

const form = useForm({
  code:    props.currency.code    || "",
  name:    props.currency.name    || "",
  symbol:  props.currency.symbol  || "",
  default: props.currency.default || false,
});

const submit = () => {
  const url    = props.currency.id ? `/currencies/${props.currency.id}` : "/currencies";
  const method = props.currency.id ? "put" : "post";
  form[method](url);
};
</script>

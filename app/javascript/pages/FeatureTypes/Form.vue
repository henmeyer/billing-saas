<template>
  <AppLayout>
    <div class="page-header">
      <div class="flex items-center gap-3">
        <Link href="/feature_types" class="text-sm text-gray-500 hover:text-gray-700">
          ← Features
        </Link>
        <h2 class="page-title">
          {{ featureType.id ? "Editar feature" : "Nova feature" }}
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
              placeholder="ex: ai_enabled"
              :readonly="!!featureType.id"
            />
            <p class="form-hint">Usado no payload do webhook. Não pode ser alterado após a criação.</p>
          </div>
          <div>
            <label class="form-label">Label</label>
            <input
              v-model="form.label"
              type="text"
              class="form-input"
              placeholder="ex: IA habilitada"
            />
          </div>
          <div>
            <label class="form-label">Descrição <span class="text-gray-400 font-normal">(opcional)</span></label>
            <textarea
              v-model="form.description"
              rows="2"
              class="form-input"
              placeholder="Descreva o que esta feature controla"
            />
          </div>
        </div>
      </div>

      <div class="flex gap-3 justify-end">
        <Link href="/feature_types" class="btn-secondary">Cancelar</Link>
        <button @click="submit" :disabled="form.processing" class="btn-primary">
          {{ form.processing ? "Salvando..." : featureType.id ? "Salvar" : "Criar" }}
        </button>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { Link, useForm } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";

const props = defineProps({
  feature_type: Object,
  errors: { type: Object, default: () => ({}) },
});

const featureType = props.feature_type || {};

const form = useForm({
  key:         featureType.key         || "",
  label:       featureType.label       || "",
  description: featureType.description || "",
});

const submit = () => {
  const url    = featureType.id ? `/feature_types/${featureType.id}` : "/feature_types";
  const method = featureType.id ? "put" : "post";
  form[method](url);
};
</script>

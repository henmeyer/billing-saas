<template>
  <AppLayout>
    <div class="page-header">
      <div class="flex items-center gap-3">
        <Link href="/license_types" class="text-sm text-gray-500 hover:text-gray-700">
          ← Tipos de licença
        </Link>
        <h2 class="page-title">
          {{ licenseType.id ? "Editar tipo de licença" : "Novo tipo de licença" }}
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
              placeholder="ex: user_licenses"
              :readonly="!!licenseType.id"
            />
            <p class="form-hint">Usado na API. Não pode ser alterado após a criação.</p>
          </div>
          <div>
            <label class="form-label">Label</label>
            <input
              v-model="form.label"
              type="text"
              class="form-input"
              placeholder="ex: Usuários"
            />
          </div>
          <div>
            <label class="form-label">Unidade</label>
            <input
              v-model="form.unit"
              type="text"
              class="form-input"
              placeholder="ex: usuário"
            />
            <p class="form-hint">Singular. Ex: usuário, agente, workspace</p>
          </div>
        </div>
      </div>

      <div class="flex gap-3 justify-end">
        <Link href="/license_types" class="btn-secondary">Cancelar</Link>
        <button @click="submit" :disabled="form.processing" class="btn-primary">
          {{ form.processing ? "Salvando..." : licenseType.id ? "Salvar" : "Criar" }}
        </button>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { Link, useForm } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";

const props = defineProps({
  license_type: Object,
  errors: { type: Object, default: () => ({}) },
});

const licenseType = props.license_type || {};

const form = useForm({
  key:   licenseType.key   || "",
  label: licenseType.label || "",
  unit:  licenseType.unit  || "",
});

const submit = () => {
  const url    = licenseType.id ? `/license_types/${licenseType.id}` : "/license_types";
  const method = licenseType.id ? "put" : "post";
  form[method](url);
};
</script>

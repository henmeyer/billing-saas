<template>
  <AppLayout>
    <div class="page-header">
      <div class="flex items-center gap-3">
        <Link href="/payment_gateways" class="text-sm text-gray-500 hover:text-gray-700">
          ← Gateways
        </Link>
        <h2 class="page-title">
          {{ gateway.id ? "Editar gateway" : "Configurar gateway" }}
        </h2>
      </div>
    </div>

    <div class="max-w-lg space-y-6">
      <div v-if="Object.keys(errors).length" class="alert-danger">
        <p v-for="(msgs, field) in errors" :key="field">{{ msgs.join(", ") }}</p>
      </div>

      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Configuração</h3>
        </div>
        <div class="card-body space-y-4">
          <div>
            <label class="form-label">Provider</label>
            <select v-model="form.provider" class="form-input" :disabled="!!gateway.id">
              <option value="">Selecione</option>
              <option v-for="p in providers" :key="p" :value="p">{{ p }}</option>
            </select>
          </div>

          <div>
            <label class="form-label">
              API Key
              <span v-if="gateway.id" class="text-gray-400 font-normal">
                (deixe em branco para manter a atual)
              </span>
            </label>
            <input
              v-model="form.api_key"
              type="password"
              class="form-input font-mono"
              autocomplete="new-password"
              :placeholder="gateway.id ? '••••••••••••••••' : 'sk_live_...'"
            />
            <p class="form-hint">Armazenada criptografada. Nunca exibida novamente.</p>
          </div>
        </div>
      </div>

      <div class="flex gap-3 justify-end">
        <Link href="/payment_gateways" class="btn-secondary">Cancelar</Link>
        <button @click="submit" :disabled="form.processing" class="btn-primary">
          {{ form.processing ? "Salvando..." : gateway.id ? "Salvar" : "Configurar" }}
        </button>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { Link, useForm } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";

const props = defineProps({
  gateway:   Object,
  providers: Array,
  errors:    { type: Object, default: () => ({}) },
});

const gateway   = props.gateway   || {};
const providers = props.providers || [];

const form = useForm({
  provider: gateway.provider || "",
  api_key:  "",
});

const submit = () => {
  const url    = gateway.id ? `/payment_gateways/${gateway.id}` : "/payment_gateways";
  const method = gateway.id ? "put" : "post";
  form[method](url);
};
</script>

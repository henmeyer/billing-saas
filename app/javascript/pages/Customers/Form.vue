<template>
  <AppLayout>
    <div class="page-header">
      <div class="flex items-center gap-3">
        <Link href="/customers" class="text-sm text-gray-500 hover:text-gray-700">← Clientes</Link>
        <h2 class="page-title">{{ customer.id ? "Editar cliente" : "Novo cliente" }}</h2>
      </div>
    </div>

    <div class="max-w-2xl space-y-6">
      <!-- Erros -->
      <div v-if="Object.keys(errors).length" class="alert-danger">
        <div>
          <p v-for="(msgs, field) in errors" :key="field">{{ msgs.join(", ") }}</p>
        </div>
      </div>

      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Informações do cliente</h3>
        </div>
        <div class="card-body space-y-4">
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="form-label">Nome</label>
              <input v-model="form.name" type="text" class="form-input" placeholder="Nome completo" required />
            </div>
            <div>
              <label class="form-label">E-mail</label>
              <input v-model="form.email" type="email" class="form-input" placeholder="cliente@empresa.com" required />
            </div>
          </div>

          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="form-label">CPF/CNPJ</label>
              <input v-model="form.document" type="text" class="form-input" placeholder="000.000.000-00" />
            </div>
            <div>
              <label class="form-label">Telefone</label>
              <input v-model="form.phone" type="text" class="form-input" placeholder="(11) 99999-9999" />
            </div>
          </div>

          <div>
            <label class="form-label">ID externo</label>
            <input
              v-model="form.external_id"
              type="text"
              class="form-input"
              placeholder="ID do cliente no seu sistema"
            />
            <p class="form-hint">Usado para sincronização via API</p>
          </div>

          <div v-if="customer.id">
            <label class="form-label">Status</label>
            <select v-model="form.status" class="form-input">
              <option value="active">Ativo</option>
              <option value="churned">Cancelado</option>
              <option value="suspended">Suspenso</option>
            </select>
          </div>

          <div>
            <label class="form-label">Observações</label>
            <textarea v-model="form.notes" rows="3" class="form-input" placeholder="Informações adicionais..." />
          </div>
        </div>
      </div>

      <div class="flex gap-3 justify-end">
        <Link href="/customers" class="btn-secondary">Cancelar</Link>
        <button @click="submit" :disabled="form.processing" class="btn-primary">
          {{ form.processing ? "Salvando..." : customer.id ? "Salvar alterações" : "Criar cliente" }}
        </button>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { Link, useForm } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";

const props = defineProps({
  customer: Object,
  errors: Object,
});

const form = useForm({
  name: props.customer.name || "",
  email: props.customer.email || "",
  document: props.customer.document || "",
  phone: props.customer.phone || "",
  external_id: props.customer.external_id || "",
  status: props.customer.status || "active",
  notes: props.customer.notes || "",
});

const submit = () => {
  const url = props.customer.id ? `/customers/${props.customer.id}` : "/customers";
  const method = props.customer.id ? "put" : "post";
  form[method](url);
};
</script>

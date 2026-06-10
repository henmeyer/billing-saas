<template>
  <AppLayout>
    <div class="page-header">
      <div class="flex items-center gap-3">
        <Link
          href="/customers"
          class="text-sm text-gray-500 hover:text-gray-700"
          >← Clientes</Link
        >
        <h2 class="page-title">
          {{ customer.id ? "Editar cliente" : "Novo cliente" }}
        </h2>
      </div>
    </div>

    <div class="max-w-2xl space-y-6">
      <!-- Erros -->
      <div v-if="Object.keys(errors).length" class="alert-danger">
        <div>
          <p v-for="(msgs, field) in errors" :key="field">
            {{ msgs.join(", ") }}
          </p>
        </div>
      </div>

      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">
            Informações do cliente
          </h3>
        </div>
        <div class="card-body space-y-4">
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="form-label">Nome</label>
              <input
                v-model="form.name"
                type="text"
                class="form-input"
                placeholder="Nome completo"
                required
              />
            </div>
            <div>
              <label class="form-label">E-mail</label>
              <input
                v-model="form.email"
                type="email"
                class="form-input"
                placeholder="cliente@empresa.com"
                required
              />
            </div>
          </div>

          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="form-label">CPF/CNPJ</label>
              <input
                v-model="form.document"
                type="text"
                class="form-input"
                placeholder="000.000.000-00"
              />
            </div>
            <div>
              <label class="form-label">Telefone</label>
              <input
                v-model="form.phone"
                type="text"
                class="form-input"
                placeholder="(11) 99999-9999"
              />
            </div>
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
            <label class="form-label">Moeda preferida</label>
            <select v-model.number="form.currency_id" class="form-input">
              <option value="">Usar padrão da conta</option>
              <option v-for="c in currencies" :key="c.id" :value="c.id">
                {{ c.code }} — {{ c.name }} ({{ c.symbol }})
              </option>
            </select>
            <p class="form-hint">
              Usada como padrão ao criar assinaturas para este cliente.
            </p>
          </div>

          <div>
            <label class="form-label">Observações</label>
            <textarea
              v-model="form.notes"
              rows="3"
              class="form-input"
              placeholder="Informações adicionais..."
            />
          </div>
        </div>
      </div>

      <!-- Identidades por integração -->
      <div v-if="integrations.length" class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">
            Identidades por integração
          </h3>
          <p class="text-xs text-gray-500 mt-0.5">
            ID deste cliente em cada sistema integrado. Usado pela API para
            identificar o cliente.
          </p>
        </div>
        <div class="card-body space-y-3">
          <div
            v-for="integration in integrations"
            :key="integration.id"
            class="flex items-center gap-3"
          >
            <div class="flex-1">
              <p class="text-sm font-medium text-gray-700">
                {{ integration.name }}
              </p>
              <p class="text-xs text-gray-400 font-mono">
                {{ integration.url }}
              </p>
            </div>
            <div class="w-48">
              {{ identities }}
              <input
                v-model="identities[integration.id]"
                type="text"
                class="form-input text-sm font-mono"
                :placeholder="`ID no ${integration.name}`"
              />
            </div>
          </div>
        </div>
      </div>

      <div class="flex gap-3 justify-end">
        <Link href="/customers" class="btn-secondary">Cancelar</Link>
        <button @click="submit" :disabled="form.processing" class="btn-primary">
          {{
            form.processing
              ? "Salvando..."
              : customer.id
                ? "Salvar alterações"
                : "Criar cliente"
          }}
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
  customer: Object,
  currencies: { type: Array, default: () => [] },
  integrations: { type: Array, default: () => [] },
  errors: Object,
});

const currencies = props.currencies;

const form = useForm({
  name: props.customer.name || "",
  email: props.customer.email || "",
  document: props.customer.document || "",
  phone: props.customer.phone || "",
  status: props.customer.status || "active",
  currency_id: props.customer.currency_id || "",
  notes: props.customer.notes || "",
});

const identities = reactive(
  Object.fromEntries(
    props.integrations.map((integration) => {
      const existing = props.customer.identities?.find(
        (id) => id.integration_id === integration.id,
      );
      return [integration.id, existing?.external_id || ""];
    }),
  ),
);

const submit = () => {
  const url = props.customer.id
    ? `/customers/${props.customer.id}`
    : "/customers";
  const method = props.customer.id ? "put" : "post";
  form.transform((data) => ({ ...data, identities }))[method](url);
};
</script>

<template>
  <AppLayout>
    <div class="page-header">
      <div>
        <h2 class="page-title">Assinaturas</h2>
        <p class="text-sm text-gray-500 mt-0.5">Todas as assinaturas ativas e encerradas</p>
      </div>
      <div class="flex items-center gap-2">
        <template v-if="pickingCustomer">
          <select
            v-model="selectedCustomerId"
            class="form-input w-56 text-sm"
            autofocus
          >
            <option value="">Selecione o cliente…</option>
            <option v-for="c in customers" :key="c.id" :value="c.id">
              {{ c.name }}
            </option>
          </select>
          <button
            :disabled="!selectedCustomerId"
            @click="goToNew"
            class="btn-primary"
          >
            Continuar
          </button>
          <button @click="pickingCustomer = false" class="btn-secondary">
            Cancelar
          </button>
        </template>
        <button v-else @click="pickingCustomer = true" class="btn-primary">
          + Nova assinatura
        </button>
      </div>
    </div>

    <div v-if="!subscriptions.length" class="card">
      <div class="card-body text-center py-12">
        <p class="text-gray-400 text-sm">Nenhuma assinatura encontrada.</p>
      </div>
    </div>

    <div v-else class="card">
      <div class="table-wrapper">
        <table class="table">
          <thead>
            <tr>
              <th>Cliente</th>
              <th>Plano</th>
              <th>Gateway</th>
              <th>Status</th>
              <th>Próxima renovação</th>
              <th>Início</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="s in subscriptions" :key="s.id">
              <td>
                <Link
                  :href="`/customers/${s.customer.id}`"
                  class="font-medium text-gray-900 hover:text-brand-600"
                >
                  {{ s.customer.name }}
                </Link>
              </td>
              <td>
                <p class="text-sm text-gray-900">{{ s.plan_name }}</p>
                <p class="text-xs text-gray-400">
                  {{ fmt(s.price) }}/{{ s.billing_cycle === "monthly" ? "mês" : "ano" }}
                </p>
              </td>
              <td>
                <Badge variant="gray">{{ s.gateway }}</Badge>
              </td>
              <td>
                <Badge :variant="statusVariant(s.status)">{{ statusLabel(s.status) }}</Badge>
              </td>
              <td class="text-sm text-gray-500">{{ s.current_period_end || "—" }}</td>
              <td class="text-sm text-gray-500">{{ s.started_at || "—" }}</td>
              <td class="text-right">
                <Link
                  :href="`/customers/${s.customer.id}/subscriptions/${s.id}/edit`"
                  class="btn-secondary btn-sm"
                >
                  Editar
                </Link>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { ref } from "vue";
import { Link, router } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";
import Badge from "@/components/Shared/Badge.vue";

defineProps({ subscriptions: Array, customers: { type: Array, default: () => [] } });

const pickingCustomer  = ref(false);
const selectedCustomerId = ref("");

const goToNew = () => {
  if (selectedCustomerId.value)
    router.visit(`/customers/${selectedCustomerId.value}/subscriptions/new`);
};

const fmt = (v) =>
  new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(v || 0);

const statusVariant = (s) =>
  ({ active: "green", past_due: "red", trialing: "blue", cancelled: "gray" })[s] || "yellow";

const statusLabel = (s) =>
  ({ active: "Ativo", past_due: "Inadimplente", trialing: "Trial", cancelled: "Cancelado" })[s] || s;
</script>

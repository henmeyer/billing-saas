<template>
  <AppLayout>
    <div class="page-header">
      <div>
        <h2 class="page-title">Clientes</h2>
        <p class="text-sm text-gray-500 mt-0.5">{{ customers.length }} clientes</p>
      </div>
      <Link href="/customers/new" class="btn-primary">Novo cliente</Link>
    </div>

    <div class="card">
      <div class="table-wrapper">
        <table class="table">
          <thead>
            <tr>
              <th>Cliente</th>
              <th>Plano</th>
              <th>Status</th>
              <th>Health</th>
              <th>Gateway</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="!customers.length">
              <td colspan="6" class="text-center text-gray-400 py-8">
                Nenhum cliente cadastrado ainda.
              </td>
            </tr>
            <tr v-for="c in customers" :key="c.id">
              <td>
                <p class="font-medium text-gray-900">{{ c.name }}</p>
                <p class="text-xs text-gray-400">{{ c.email }}</p>
              </td>
              <td>
                <span v-if="c.plan_name" class="text-sm text-gray-700">{{ c.plan_name }}</span>
                <span v-else class="text-sm text-gray-400">—</span>
              </td>
              <td>
                <Badge :variant="statusVariant(c.status)">{{ statusLabel(c.status) }}</Badge>
                <Badge v-if="c.sub_status === 'past_due'" variant="red" class="ml-1">
                  Inadimplente
                </Badge>
              </td>
              <td>
                <span :class="['text-sm font-medium', healthClass(c.health_score)]">
                  {{ c.health_score }}%
                </span>
              </td>
              <td>
                <Badge v-if="c.gateway" variant="gray">{{ c.gateway }}</Badge>
                <span v-else class="text-gray-400 text-sm">—</span>
              </td>
              <td class="text-right">
                <Link :href="`/customers/${c.id}`" class="btn-secondary btn-sm">Ver</Link>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { Link } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";
import Badge from "@/components/Shared/Badge.vue";

defineProps({ customers: Array });

const statusVariant = (s) =>
  ({ active: "green", churned: "gray", suspended: "red", trial: "blue" })[s] || "yellow";
const statusLabel = (s) =>
  ({ active: "Ativo", churned: "Cancelado", suspended: "Suspenso", trial: "Trial" })[s] || s;
const healthClass = (s) =>
  s >= 70 ? "text-green-600" : s >= 40 ? "text-yellow-600" : "text-red-600";
</script>

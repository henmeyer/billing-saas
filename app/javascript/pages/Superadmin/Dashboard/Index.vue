<template>
  <AppLayout>
    <div class="page-header">
      <h2 class="page-title">Painel SuperAdmin</h2>
    </div>

    <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
      <StatCard label="Contas ativas" :value="stats.active_accounts" />
      <StatCard label="Contas suspensas" :value="stats.suspended_accounts" />
      <StatCard label="Usuários" :value="stats.users_count" />
      <StatCard label="SuperAdmins" :value="stats.super_admins_count" />
    </div>

    <div class="card">
      <div class="card-header">
        <h3 class="text-sm font-medium text-gray-900">Contas recentes</h3>
        <Link href="/superadmin/accounts" class="text-xs text-brand-600 hover:underline">
          Ver todas
        </Link>
      </div>
      <div class="table-wrapper border-0 rounded-none">
        <table class="table">
          <thead>
            <tr>
              <th>Conta</th>
              <th>Status</th>
              <th>Criada em</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="a in recentAccounts" :key="a.id">
              <td>
                <p class="font-medium text-gray-900">{{ a.name }}</p>
                <p class="text-xs text-gray-400 font-mono">{{ a.slug }}</p>
              </td>
              <td>
                <Badge :variant="a.status === 'active' ? 'green' : 'red'">
                  {{ a.status }}
                </Badge>
              </td>
              <td class="text-gray-500 text-sm">{{ a.created_at }}</td>
              <td class="text-right">
                <Link :href="`/superadmin/accounts/${a.id}`" class="btn-secondary btn-sm">
                  Ver
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
import { Link } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";
import StatCard from "@/components/Shared/StatCard.vue";
import Badge from "@/components/Shared/Badge.vue";

const props = defineProps({
  stats:           Object,
  recent_accounts: Array,
});

const recentAccounts = props.recent_accounts || [];
</script>

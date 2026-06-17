<template>
  <AppLayout>
    <div class="page-header">
      <div class="flex items-center gap-3">
        <Link href="/superadmin/accounts" class="text-sm text-gray-500 hover:text-gray-700">
          ← Contas
        </Link>
        <h2 class="page-title">{{ account.name }}</h2>
        <Badge :variant="account.status === 'active' ? 'green' : 'red'">
          {{ account.status }}
        </Badge>
      </div>
      <div class="flex gap-2">
        <Link :href="`/superadmin/accounts/${account.id}/edit`" class="btn-secondary">
          Editar
        </Link>
        <ConfirmButton
          v-if="account.status === 'active'"
          :message="`Suspender a conta '${account.name}'?`"
          btn-class="btn-danger"
          @confirm="suspend"
        >
          Suspender
        </ConfirmButton>
        <ConfirmButton
          v-else
          :message="`Reativar a conta '${account.name}'?`"
          btn-class="btn-primary"
          @confirm="activate"
        >
          Reativar
        </ConfirmButton>
      </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
      <!-- Info -->
      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Informações</h3>
        </div>
        <div class="card-body space-y-3">
          <div>
            <p class="text-xs text-gray-500">Nome</p>
            <p class="text-sm text-gray-900">{{ account.name }}</p>
          </div>
          <div>
            <p class="text-xs text-gray-500">Slug</p>
            <p class="text-sm font-mono text-gray-700">{{ account.slug }}</p>
          </div>
          <div>
            <p class="text-xs text-gray-500">Criada em</p>
            <p class="text-sm text-gray-900">{{ account.created_at }}</p>
          </div>
        </div>
        <div class="card-header border-t">
          <h3 class="text-sm font-medium text-gray-900">Recursos</h3>
        </div>
        <div class="card-body grid grid-cols-3 gap-2 text-center">
          <div>
            <p class="text-lg font-semibold text-gray-900">{{ stats.plans_count }}</p>
            <p class="text-xs text-gray-500">Planos</p>
          </div>
          <div>
            <p class="text-lg font-semibold text-gray-900">{{ stats.customers_count }}</p>
            <p class="text-xs text-gray-500">Clientes</p>
          </div>
          <div>
            <p class="text-lg font-semibold text-gray-900">{{ stats.api_keys_count }}</p>
            <p class="text-xs text-gray-500">API Keys</p>
          </div>
        </div>
      </div>

      <!-- Colaboradores -->
      <div class="lg:col-span-2 card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Colaboradores ({{ members.length }})</h3>
        </div>
        <div v-if="!members.length" class="card-body text-sm text-gray-400">
          Sem colaboradores.
        </div>
        <div v-else class="table-wrapper border-0 rounded-none">
          <table class="table">
            <thead>
              <tr>
                <th>Usuário</th>
                <th>Role</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="m in members" :key="m.id">
                <td>
                  <p class="font-medium text-gray-900">{{ m.name }}</p>
                  <p class="text-xs text-gray-400">{{ m.email }}</p>
                </td>
                <td>
                  <Badge variant="gray">{{ m.role }}</Badge>
                </td>
                <td class="text-right">
                  <Link :href="`/superadmin/users/${m.id}`" class="btn-secondary btn-sm">
                    Ver usuário
                  </Link>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { Link, router } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";
import Badge from "@/components/Shared/Badge.vue";
import ConfirmButton from "@/components/Shared/ConfirmButton.vue";

const props = defineProps({
  account: Object,
  members: Array,
  stats:   Object,
});

const suspend  = () => router.post(`/superadmin/accounts/${props.account.id}/suspend`);
const activate = () => router.post(`/superadmin/accounts/${props.account.id}/activate`);
</script>

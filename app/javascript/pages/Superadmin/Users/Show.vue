<template>
  <AppLayout>
    <div class="page-header">
      <div class="flex items-center gap-3">
        <Link href="/superadmin/users" class="text-sm text-gray-500 hover:text-gray-700">
          ← Usuários
        </Link>
        <h2 class="page-title">{{ user.name }}</h2>
      </div>
      <ConfirmButton
        :message="`Entrar como ${user.name}?`"
        btn-class="btn-secondary"
        @confirm="impersonate"
      >
        Impersonar
      </ConfirmButton>
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
            <p class="text-sm text-gray-900">{{ user.name }}</p>
          </div>
          <div>
            <p class="text-xs text-gray-500">E-mail</p>
            <p class="text-sm text-gray-900">{{ user.email }}</p>
          </div>
          <div>
            <p class="text-xs text-gray-500">Cadastro</p>
            <p class="text-sm text-gray-900">{{ user.created_at }}</p>
          </div>
        </div>
      </div>

      <!-- Contas -->
      <div class="lg:col-span-2 card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Contas ({{ accounts.length }})</h3>
        </div>
        <div v-if="!accounts.length" class="card-body text-sm text-gray-400">
          Sem contas vinculadas.
        </div>
        <div v-else class="table-wrapper border-0 rounded-none">
          <table class="table">
            <thead>
              <tr>
                <th>Conta</th>
                <th>Role</th>
                <th>Status</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="a in accounts" :key="a.id">
                <td>
                  <p class="font-medium text-gray-900">{{ a.name }}</p>
                  <p class="text-xs text-gray-400 font-mono">{{ a.slug }}</p>
                </td>
                <td>
                  <Badge variant="gray">{{ a.role }}</Badge>
                </td>
                <td>
                  <Badge :variant="a.status === 'active' ? 'green' : 'red'">
                    {{ a.status }}
                  </Badge>
                </td>
                <td class="text-right">
                  <Link :href="`/superadmin/accounts/${a.id}`" class="btn-secondary btn-sm">
                    Ver conta
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
  user:     Object,
  accounts: Array,
});

const impersonate = () => router.post(`/superadmin/users/${props.user.id}/impersonate`);
</script>

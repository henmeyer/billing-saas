<template>
  <SuperadminLayout>
    <div class="page-header">
      <div>
        <h2 class="page-title">Contas</h2>
        <p class="text-sm text-gray-500 mt-0.5">{{ accounts.length }} contas cadastradas</p>
      </div>
    </div>

    <div class="mb-4">
      <input
        v-model="search"
        type="text"
        class="form-input max-w-sm"
        placeholder="Buscar por nome ou slug..."
      />
    </div>

    <div class="card">
      <div class="table-wrapper">
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
            <tr v-if="!filteredAccounts.length">
              <td colspan="4" class="text-center text-gray-400 py-8">
                Nenhuma conta encontrada.
              </td>
            </tr>
            <tr v-for="a in filteredAccounts" :key="a.id">
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
  </SuperadminLayout>
</template>

<script setup>
import { ref, computed } from "vue";
import { Link } from "@inertiajs/vue3";
import SuperadminLayout from "@/components/Layout/SuperadminLayout.vue";
import Badge from "@/components/Shared/Badge.vue";

const props = defineProps({ accounts: Array });

const search = ref("");

const filteredAccounts = computed(() => {
  if (!search.value) return props.accounts;
  const q = search.value.toLowerCase();
  return props.accounts.filter(
    (a) => a.name.toLowerCase().includes(q) || a.slug.toLowerCase().includes(q),
  );
});
</script>

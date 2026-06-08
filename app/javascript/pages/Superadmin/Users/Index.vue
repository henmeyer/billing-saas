<template>
  <SuperadminLayout>
    <div class="page-header">
      <div>
        <h2 class="page-title">Usuários</h2>
        <p class="text-sm text-gray-500 mt-0.5">{{ users.length }} usuários cadastrados</p>
      </div>
    </div>

    <div class="mb-4">
      <input
        v-model="search"
        type="text"
        class="form-input max-w-sm"
        placeholder="Buscar por nome ou e-mail..."
      />
    </div>

    <div class="card">
      <div class="table-wrapper">
        <table class="table">
          <thead>
            <tr>
              <th>Usuário</th>
              <th>Contas</th>
              <th>Cadastro</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="!filteredUsers.length">
              <td colspan="4" class="text-center text-gray-400 py-8">
                Nenhum usuário encontrado.
              </td>
            </tr>
            <tr v-for="u in filteredUsers" :key="u.id">
              <td>
                <p class="font-medium text-gray-900">{{ u.name }}</p>
                <p class="text-xs text-gray-400">{{ u.email }}</p>
              </td>
              <td class="text-gray-500">{{ u.accounts_count }}</td>
              <td class="text-gray-500 text-sm">{{ u.created_at }}</td>
              <td class="text-right flex gap-2 justify-end">
                <Link :href="`/superadmin/users/${u.id}`" class="btn-secondary btn-sm">
                  Ver
                </Link>
                <ConfirmButton
                  :message="`Entrar como ${u.name}?`"
                  btn-class="btn-secondary btn-sm"
                  @confirm="impersonate(u.id)"
                >
                  Impersonar
                </ConfirmButton>
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
import { Link, router } from "@inertiajs/vue3";
import SuperadminLayout from "@/components/Layout/SuperadminLayout.vue";
import ConfirmButton from "@/components/Shared/ConfirmButton.vue";

const props = defineProps({ users: Array });

const search = ref("");

const filteredUsers = computed(() => {
  if (!search.value) return props.users;
  const q = search.value.toLowerCase();
  return props.users.filter(
    (u) => u.name.toLowerCase().includes(q) || u.email.toLowerCase().includes(q),
  );
});

const impersonate = (id) => router.post(`/superadmin/users/${id}/impersonate`);
</script>

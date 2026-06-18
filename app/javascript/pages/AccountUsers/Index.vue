<template>
  <AppLayout>
    <div class="page-header">
      <div>
        <h2 class="page-title">Colaboradores</h2>
        <p class="text-sm text-gray-500 mt-0.5">{{ account_users.length }} colaboradores nesta conta</p>
      </div>
      <Link v-if="can.manage_members" href="/account_users/new" class="btn-primary">
        Adicionar colaborador
      </Link>
    </div>

    <div class="card">
      <div class="table-wrapper">
        <table class="table">
          <thead>
            <tr>
              <th>Usuário</th>
              <th>E-mail</th>
              <th>Permissão</th>
              <th v-if="can.manage_members"></th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="!account_users.length">
              <td colspan="4" class="text-center text-gray-400 py-8">
                Nenhum colaborador encontrado.
              </td>
            </tr>
            <tr v-for="au in account_users" :key="au.id">
              <td class="font-medium text-gray-900">
                <div class="flex items-center gap-2">
                  <UserAvatar
                    :avatar-url="au.user.avatar_url"
                    :name="au.user.name"
                    :initials="au.user.initials"
                    size="sm"
                  />
                  {{ au.user.name }}
                </div>
              </td>
              <td class="text-sm text-gray-500">{{ au.user.email }}</td>
              <td>
                <Badge :variant="roleBadge(au.role)">{{ roleLabel(au.role) }}</Badge>
              </td>
              <td v-if="can.manage_members" class="text-right">
                <div class="flex gap-2 justify-end">
                  <Link
                    :href="`/account_users/${au.id}/edit`"
                    class="btn-secondary btn-sm"
                  >
                    Editar
                  </Link>
                  <ConfirmButton
                    :message="`Remover ${au.user.name} da conta?`"
                    btn-class="btn-danger btn-sm"
                    @confirm="remove(au.id)"
                  >
                    Remover
                  </ConfirmButton>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { Link, router } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";
import Badge from "@/components/Shared/Badge.vue";
import ConfirmButton from "@/components/Shared/ConfirmButton.vue";
import UserAvatar from "@/components/Shared/UserAvatar.vue";
import { usePermissions } from "@/composables/usePermissions";

defineProps({ account_users: Array });

const { can } = usePermissions();

const remove = (id) => router.delete(`/account_users/${id}`, { preserveState: false });

const roleLabel = (r) =>
  ({ owner: "Owner", admin: "Admin", manager: "Manager", seller: "Vendedor", member: "Colaborador" })[r] || r;

const roleBadge = (r) =>
  ({ owner: "purple", admin: "blue", manager: "green", seller: "yellow", member: "gray" })[r] || "gray";
</script>

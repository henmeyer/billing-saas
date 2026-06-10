<template>
  <AppLayout>
    <div class="page-header">
      <div>
        <h2 class="page-title">SuperAdmins</h2>
        <p class="text-sm text-gray-500 mt-0.5">Gerenciar acesso de superadmin</p>
      </div>
      <Link href="/superadmin/super_admins/new" class="btn-primary">Novo SuperAdmin</Link>
    </div>

    <div class="alert-warning mb-6">
      <span>⚠</span>
      <span>
        SuperAdmins têm acesso irrestrito a todas as contas e dados. Adicione apenas pessoas de
        total confiança.
      </span>
    </div>

    <div class="card">
      <div class="table-wrapper">
        <table class="table">
          <thead>
            <tr>
              <th>Nome</th>
              <th>E-mail</th>
              <th>Criado em</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="sa in superAdmins" :key="sa.id">
              <td>
                <div class="flex items-center gap-2">
                  <p class="font-medium text-gray-900">{{ sa.name }}</p>
                  <Badge v-if="sa.id === currentId" variant="blue">Você</Badge>
                </div>
              </td>
              <td class="text-gray-500">{{ sa.email }}</td>
              <td class="text-gray-500 text-sm">{{ sa.created_at }}</td>
              <td class="text-right">
                <ConfirmButton
                  v-if="sa.id !== currentId"
                  :message="`Remover ${sa.name} como SuperAdmin?`"
                  @confirm="remove(sa.id)"
                >
                  Remover
                </ConfirmButton>
                <span v-else class="text-xs text-gray-400">—</span>
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

const props = defineProps({
  super_admins: Array,
  current_id:   Number,
});

const superAdmins = props.super_admins || [];
const currentId   = props.current_id;

const remove = (id) => router.delete(`/superadmin/super_admins/${id}`);
</script>

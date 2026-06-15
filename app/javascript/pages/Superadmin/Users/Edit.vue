<template>
  <AppLayout>
    <div class="page-header">
      <div class="flex items-center gap-3">
        <Link
          :href="`/superadmin/users/${user.id}`"
          class="text-sm text-gray-500 hover:text-gray-700"
        >
          ← {{ user.name }}
        </Link>
        <h2 class="page-title">Editar usuário</h2>
      </div>
    </div>

    <div class="max-w-md space-y-6">
      <div v-if="Object.keys(errors).length" class="alert-danger">
        <p v-for="(err, key) in errors" :key="key">{{ err }}</p>
      </div>

      <!-- Dados básicos -->
      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Informações</h3>
        </div>
        <div class="card-body space-y-4">
          <div>
            <label class="form-label">Nome</label>
            <input v-model="form.name" type="text" class="form-input" />
          </div>
          <div>
            <label class="form-label">E-mail</label>
            <input v-model="form.email" type="email" class="form-input" />
          </div>
        </div>
      </div>

      <!-- Alterar senha -->
      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Alterar senha</h3>
          <p class="text-xs text-gray-500 mt-0.5">Deixe em branco para manter a senha atual.</p>
        </div>
        <div class="card-body space-y-4">
          <div>
            <label class="form-label">Nova senha</label>
            <input
              v-model="form.password"
              type="password"
              class="form-input"
              placeholder="Mínimo 8 caracteres"
              autocomplete="new-password"
            />
          </div>
          <div>
            <label class="form-label">Confirmar nova senha</label>
            <input
              v-model="form.password_confirmation"
              type="password"
              class="form-input"
              autocomplete="new-password"
            />
          </div>
        </div>
      </div>

      <!-- Contas vinculadas -->
      <div v-if="accounts.length" class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">
            Contas vinculadas ({{ accounts.length }})
          </h3>
        </div>
        <div class="divide-y divide-gray-100">
          <div
            v-for="a in accounts"
            :key="a.id"
            class="px-6 py-3 flex items-center justify-between"
          >
            <p class="text-sm font-medium text-gray-900">{{ a.name }}</p>
            <Badge variant="gray">{{ a.role }}</Badge>
          </div>
        </div>
      </div>

      <div class="flex gap-3 justify-end">
        <Link :href="`/superadmin/users/${user.id}`" class="btn-secondary">Cancelar</Link>
        <button @click="submit" :disabled="form.processing" class="btn-primary">
          {{ form.processing ? "Salvando..." : "Salvar" }}
        </button>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { Link, useForm } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";
import Badge from "@/components/Shared/Badge.vue";

const props = defineProps({
  user:     Object,
  accounts: { type: Array, default: () => [] },
  errors:   { type: Object, default: () => ({}) },
});

const form = useForm({
  name:                  props.user.name || "",
  email:                 props.user.email || "",
  password:              "",
  password_confirmation: "",
});

const submit = () => form.put(`/superadmin/users/${props.user.id}`);
</script>

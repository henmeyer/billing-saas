<template>
  <AppLayout>
    <div class="page-header">
      <div class="flex items-center gap-3">
        <Link href="/superadmin/super_admins" class="text-sm text-gray-500 hover:text-gray-700">
          ← SuperAdmins
        </Link>
        <h2 class="page-title">Novo SuperAdmin</h2>
      </div>
    </div>

    <div class="max-w-md">
      <div class="alert-warning mb-6">
        <span>⚠</span>
        <span>
          SuperAdmins têm acesso total ao sistema. Certifique-se de que esta pessoa deve ter esse
          nível de acesso.
        </span>
      </div>

      <div class="card">
        <div class="card-body space-y-4">
          <div v-if="Object.keys(errors).length" class="alert-danger">
            <p v-for="(msgs, field) in errors" :key="field">{{ msgs.join(", ") }}</p>
          </div>

          <div>
            <label class="form-label">Nome</label>
            <input
              v-model="form.name"
              type="text"
              class="form-input"
              placeholder="Nome completo"
              autofocus
            />
          </div>

          <div>
            <label class="form-label">E-mail</label>
            <input
              v-model="form.email"
              type="email"
              class="form-input"
              placeholder="email@empresa.com"
            />
          </div>

          <div>
            <label class="form-label">Senha</label>
            <input
              v-model="form.password"
              type="password"
              class="form-input"
              placeholder="Mínimo 8 caracteres"
              autocomplete="new-password"
            />
          </div>

          <div>
            <label class="form-label">Confirmar senha</label>
            <input
              v-model="form.password_confirmation"
              type="password"
              class="form-input"
              autocomplete="new-password"
            />
          </div>
        </div>
      </div>

      <div class="flex gap-3 justify-end mt-6">
        <Link href="/superadmin/super_admins" class="btn-secondary">Cancelar</Link>
        <button @click="submit" :disabled="form.processing" class="btn-primary">
          {{ form.processing ? "Criando..." : "Criar SuperAdmin" }}
        </button>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { Link, useForm } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";

defineProps({
  errors: { type: Object, default: () => ({}) },
});

const form = useForm({
  name:                  "",
  email:                 "",
  password:              "",
  password_confirmation: "",
});

const submit = () => form.post("/superadmin/super_admins");
</script>

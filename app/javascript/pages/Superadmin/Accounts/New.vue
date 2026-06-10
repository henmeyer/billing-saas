<template>
  <AppLayout>
    <div class="page-header">
      <div class="flex items-center gap-3">
        <Link
          href="/superadmin/accounts"
          class="text-sm text-gray-500 hover:text-gray-700"
        >
          ← Contas
        </Link>
        <h2 class="page-title">Nova conta</h2>
      </div>
    </div>

    <div class="max-w-md">
      <div class="alert-warning mb-6">
        <span>⚠</span>
        <span>
          Você está criando uma nova conta SaaS como SuperAdmin. Um usuário
          owner será criado automaticamente.
        </span>
      </div>

      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Dados da conta</h3>
        </div>
        <div class="card-body space-y-4">
          <div v-if="errors.length" class="alert-danger">
            <div>
              <p
                v-for="err in Array.isArray(errors) ? errors : [errors]"
                :key="err"
              >
                {{ err }}
              </p>
            </div>
          </div>

          <div>
            <label class="form-label">Nome da empresa</label>
            <input
              v-model="form.company_name"
              type="text"
              class="form-input"
              placeholder="Empresa Ltda"
              autofocus
            />
          </div>

          <div class="border-t border-gray-100 pt-4">
            <p
              class="text-xs font-medium text-gray-500 uppercase
                      tracking-wider mb-3"
            >
              Usuário Owner
            </p>

            <div class="space-y-3">
              <div>
                <label class="form-label">Nome</label>
                <input
                  v-model="form.owner_name"
                  type="text"
                  class="form-input"
                  placeholder="João Silva"
                />
              </div>
              <div>
                <label class="form-label">E-mail</label>
                <input
                  v-model="form.owner_email"
                  type="email"
                  class="form-input"
                  placeholder="joao@empresa.com"
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
        </div>
      </div>

      <div class="flex gap-3 justify-end mt-6">
        <Link href="/superadmin/accounts" class="btn-secondary">
          Cancelar
        </Link>
        <button @click="submit" :disabled="form.processing" class="btn-primary">
          {{ form.processing ? "Criando..." : "Criar conta" }}
        </button>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { Link, useForm } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";

defineProps({
  errors: { type: [Array, Object], default: () => [] },
});

const form = useForm({
  company_name:          "",
  owner_name:            "",
  owner_email:           "",
  password:              "",
  password_confirmation: "",
});

const submit = () => form.post("/superadmin/accounts");
</script>

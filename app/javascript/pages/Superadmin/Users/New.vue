<template>
  <AppLayout>
    <div class="page-header">
      <div class="flex items-center gap-3">
        <Link
          href="/superadmin/users"
          class="text-sm text-gray-500 hover:text-gray-700"
        >
          ← Usuários
        </Link>
        <h2 class="page-title">Novo usuário</h2>
      </div>
    </div>

    <div class="max-w-md">
      <div class="card">
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

          <div class="border-t border-gray-100 pt-4">
            <p
              class="text-xs font-medium text-gray-500 uppercase
                      tracking-wider mb-3"
            >
              Vincular a uma conta (opcional)
            </p>

            <div class="space-y-3">
              <div>
                <label class="form-label">Conta</label>
                <select v-model.number="form.account_id" class="form-input">
                  <option value="">Sem conta por enquanto</option>
                  <option v-for="a in accounts" :key="a.id" :value="a.id">
                    {{ a.name }}
                  </option>
                </select>
              </div>

              <div v-if="form.account_id">
                <label class="form-label">Permissão</label>
                <select v-model="form.role" class="form-input">
                  <option value="member">Member</option>
                  <option value="admin">Admin</option>
                  <option value="owner">Owner</option>
                </select>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="flex gap-3 justify-end mt-6">
        <Link href="/superadmin/users" class="btn-secondary">Cancelar</Link>
        <button @click="submit" :disabled="form.processing" class="btn-primary">
          {{ form.processing ? "Criando..." : "Criar usuário" }}
        </button>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { Link, useForm } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";

defineProps({
  accounts: { type: Array, default: () => [] },
  errors:   { type: [Array, Object], default: () => [] },
});

const form = useForm({
  name:                  "",
  email:                 "",
  password:              "",
  password_confirmation: "",
  account_id:            "",
  role:                  "member",
});

const submit = () => form.post("/superadmin/users");
</script>

<template>
  <div class="min-h-full flex items-center justify-center py-12 px-4">
    <div class="w-full max-w-sm">
      <div class="text-center mb-8">
        <div class="text-3xl mb-2">💳</div>
        <h2 class="text-xl font-semibold text-gray-900">Criar conta</h2>
      </div>

      <div class="card">
        <div class="card-body">
          <div v-if="errors.length" class="alert-danger mb-4">
            <div>
              <p v-for="error in errors" :key="error">{{ error }}</p>
            </div>
          </div>

          <form @submit.prevent="submit" class="space-y-4">
            <div>
              <label class="form-label">Nome da empresa</label>
              <input
                v-model="form.company_name"
                type="text"
                class="form-input"
                placeholder="Minha Empresa Ltda"
                required
              />
            </div>
            <div>
              <label class="form-label">Seu nome</label>
              <input
                v-model="form.name"
                type="text"
                class="form-input"
                placeholder="João Silva"
                required
              />
            </div>
            <div>
              <label class="form-label">E-mail</label>
              <input
                v-model="form.email"
                type="email"
                class="form-input"
                placeholder="joao@empresa.com"
                required
              />
            </div>
            <div>
              <label class="form-label">Senha</label>
              <input
                v-model="form.password"
                type="password"
                class="form-input"
                placeholder="Mínimo 8 caracteres"
                required
              />
            </div>
            <div>
              <label class="form-label">Confirmar senha</label>
              <input
                v-model="form.password_confirmation"
                type="password"
                class="form-input"
                required
              />
            </div>

            <button
              type="submit"
              :disabled="form.processing"
              class="btn-primary w-full justify-center mt-2"
            >
              {{ form.processing ? "Criando..." : "Criar conta" }}
            </button>
          </form>
        </div>
      </div>

      <p class="mt-4 text-center text-sm text-gray-500">
        Já tem conta?
        <a href="/users/sign_in" class="text-brand-600 hover:text-brand-700 font-medium">
          Entrar
        </a>
      </p>
    </div>
  </div>
</template>

<script setup>
import { useForm } from "@inertiajs/vue3";

defineProps({
  errors: { type: Array, default: () => [] },
});

const form = useForm({
  company_name: "",
  name: "",
  email: "",
  password: "",
  password_confirmation: "",
});

const submit = () => {
  form.post("/users");
};
</script>

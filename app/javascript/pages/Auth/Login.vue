<template>
  <div class="min-h-full flex items-center justify-center py-12 px-4">
    <div class="w-full max-w-sm">
      <div class="text-center mb-8">
        <div class="text-3xl mb-2">💳</div>
        <h2 class="text-xl font-semibold text-gray-900">Entrar no Billing</h2>
        <p class="mt-1 text-sm text-gray-500">Gerencie sua receita recorrente</p>
      </div>

      <div class="card">
        <div class="card-body">
          <form @submit.prevent="submit" class="space-y-4">
            <div>
              <label class="form-label">E-mail</label>
              <input
                v-model="form.email"
                type="email"
                class="form-input"
                placeholder="seu@email.com"
                required
                autofocus
              />
              <p v-if="form.errors.email" class="form-error">{{ form.errors.email }}</p>
            </div>

            <div>
              <label class="form-label">Senha</label>
              <input
                v-model="form.password"
                type="password"
                class="form-input"
                placeholder="Sua senha"
                required
              />
              <p v-if="form.errors.password" class="form-error">{{ form.errors.password }}</p>
            </div>

            <div class="flex items-center justify-between">
              <label class="flex items-center gap-2 text-sm text-gray-600 cursor-pointer">
                <input v-model="form.remember_me" type="checkbox" class="rounded border-gray-300" />
                Lembrar
              </label>
              <a href="/users/password/new" class="text-sm text-brand-600 hover:text-brand-700">
                Esqueci a senha
              </a>
            </div>

            <button
              type="submit"
              :disabled="form.processing"
              class="btn-primary w-full justify-center mt-2"
            >
              {{ form.processing ? "Entrando..." : "Entrar" }}
            </button>
          </form>
        </div>
      </div>

      <p class="mt-4 text-center text-sm text-gray-500">
        Não tem conta?
        <a href="/users/sign_up" class="text-brand-600 hover:text-brand-700 font-medium">
          Criar conta
        </a>
      </p>
    </div>
  </div>
</template>

<script setup>
import { useForm } from "@inertiajs/vue3";

const form = useForm({
  email: "",
  password: "",
  remember_me: false,
});

const submit = () => {
  form.transform((data) => ({ user: data })).post("/users/sign_in");
};
</script>

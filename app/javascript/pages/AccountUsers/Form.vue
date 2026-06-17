<template>
  <AppLayout>
    <div class="page-header">
      <div>
        <h2 class="page-title">{{ isEdit ? "Editar colaborador" : "Adicionar colaborador" }}</h2>
        <p class="text-sm text-gray-500 mt-0.5">
          {{ isEdit ? "Altere a permissão do colaborador" : "Adicione um usuário à conta" }}
        </p>
      </div>
      <Link href="/account_users" class="btn-secondary">Voltar</Link>
    </div>

    <div class="card max-w-lg">
      <div class="card-body space-y-4">
        <form @submit.prevent="submit">
          <!-- E-mail (só no create) -->
          <div v-if="!isEdit" class="form-group">
            <label class="form-label">E-mail do usuário</label>
            <input
              v-model="form.email"
              type="email"
              class="form-input"
              placeholder="usuario@exemplo.com"
              required
            />
            <p v-if="errors.email" class="form-error">{{ errors.email[0] }}</p>
          </div>

          <!-- Nome (só no edit, readonly) -->
          <div v-if="isEdit" class="form-group">
            <label class="form-label">Usuário</label>
            <input
              :value="account_user.user?.name"
              type="text"
              class="form-input bg-gray-50"
              readonly
            />
          </div>

          <!-- Role -->
          <div class="form-group">
            <label class="form-label">Permissão</label>
            <select v-model="form.role" class="form-input" required>
              <option v-for="r in availableRoles" :key="r.value" :value="r.value">
                {{ r.label }}
              </option>
            </select>
            <p v-if="selectedRoleDesc" class="text-xs text-gray-500 mt-1">{{ selectedRoleDesc }}</p>
            <p v-if="errors.role" class="form-error">{{ errors.role[0] }}</p>
          </div>

          <div class="flex gap-3 pt-2">
            <button type="submit" class="btn-primary">
              {{ isEdit ? "Salvar" : "Adicionar" }}
            </button>
            <Link href="/account_users" class="btn-secondary">Cancelar</Link>
          </div>
        </form>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { computed, reactive } from "vue";
import { Link, router, usePage } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";

const props = defineProps({
  account_user: { type: Object, default: () => ({ email: "", role: "member" }) },
  errors:       { type: Object, default: () => ({}) },
});

const isEdit = computed(() => !!props.account_user?.id);

const form = reactive({
  email: props.account_user?.user?.email || "",
  role:  props.account_user?.role || "member",
});

const page = usePage();
const myRole = computed(() => page.props.auth?.user?.role);

const allRoles = [
  { value: "owner",   label: "Owner",    level: 50, desc: "Acesso total. Pode excluir a conta." },
  { value: "admin",   label: "Admin",    level: 40, desc: "Configura planos, gateways, integrações e tipos." },
  { value: "manager", label: "Manager",  level: 30, desc: "Gerencia clientes, assinaturas e importações." },
  { value: "seller",  label: "Vendedor", level: 20, desc: "Cria clientes e assinaturas. Não cancela nem deleta." },
  { value: "member",  label: "Colaborador", level: 10, desc: "Apenas visualização." },
];

const myLevel = computed(() => allRoles.find((r) => r.value === myRole.value)?.level || 0);

const availableRoles = computed(() => allRoles.filter((r) => r.level < myLevel.value));

const selectedRoleDesc = computed(() => allRoles.find((r) => r.value === form.role)?.desc || "");

const submit = () => {
  if (isEdit.value) {
    router.patch(`/account_users/${props.account_user.id}`, { role: form.role });
  } else {
    router.post("/account_users", { email: form.email, role: form.role });
  }
};
</script>

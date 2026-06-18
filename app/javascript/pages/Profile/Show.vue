<template>
  <AppLayout>
    <div class="page-header">
      <h2 class="page-title">Meu perfil</h2>
    </div>

    <div class="max-w-lg space-y-6">
      <!-- Foto -->
      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Foto de perfil</h3>
        </div>
        <div class="card-body">
          <div class="flex items-center gap-6">
            <UserAvatar
              :avatar-url="user.avatar_url"
              :name="user.name"
              :initials="user.initials"
              size="2xl"
            />

            <div class="space-y-2">
              <div>
                <label class="btn-secondary text-sm cursor-pointer inline-flex">
                  <input
                    type="file"
                    ref="fileInput"
                    accept="image/jpeg,image/png,image/webp"
                    class="hidden"
                    @change="uploadAvatar"
                  />
                  {{ uploading ? "Enviando..." : "Trocar foto" }}
                </label>
              </div>

              <button
                v-if="user.avatar_url"
                @click="removeAvatar"
                class="text-xs text-red-500 hover:text-red-700"
              >
                Remover foto
              </button>

              <p class="text-xs text-gray-400">JPG, PNG ou WebP. Máximo 5MB.</p>
            </div>
          </div>
        </div>
      </div>

      <!-- Informações -->
      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Informações</h3>
        </div>
        <div class="card-body space-y-4">
          <div>
            <label class="form-label">Nome</label>
            <input v-model="infoForm.name" type="text" class="form-input" />
          </div>

          <div>
            <label class="form-label">E-mail</label>
            <input :value="user.email" type="email" class="form-input" disabled />
            <p class="form-hint">
              O e-mail não pode ser alterado por aqui. Entre em contato com o
              administrador.
            </p>
          </div>

          <div>
            <label class="text-xs text-gray-400">Membro desde</label>
            <p class="text-sm text-gray-700">{{ user.created_at }}</p>
          </div>

          <div class="flex justify-end pt-2">
            <button
              @click="saveInfo"
              :disabled="infoForm.processing"
              class="btn-primary"
            >
              {{ infoForm.processing ? "Salvando..." : "Salvar" }}
            </button>
          </div>
        </div>
      </div>

      <!-- Alterar senha -->
      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Alterar senha</h3>
        </div>
        <div class="card-body space-y-4">
          <div>
            <label class="form-label">Senha atual</label>
            <input
              v-model="pwForm.current_password"
              type="password"
              class="form-input"
              autocomplete="current-password"
            />
          </div>

          <div>
            <label class="form-label">Nova senha</label>
            <input
              v-model="pwForm.password"
              type="password"
              class="form-input"
              placeholder="Mínimo 8 caracteres"
              autocomplete="new-password"
            />
          </div>

          <div>
            <label class="form-label">Confirmar nova senha</label>
            <input
              v-model="pwForm.password_confirmation"
              type="password"
              class="form-input"
              autocomplete="new-password"
            />
          </div>

          <!-- Indicador de força -->
          <div v-if="pwForm.password">
            <div class="flex gap-1 mb-1">
              <div
                v-for="i in 4"
                :key="i"
                :class="[
                  'h-1 flex-1 rounded-full',
                  i <= passwordStrength ? strengthColor : 'bg-gray-200',
                ]"
              />
            </div>
            <p class="text-xs" :class="strengthTextColor">
              {{ strengthLabel }}
            </p>
          </div>

          <div class="flex justify-end pt-2">
            <button
              @click="savePassword"
              :disabled="pwForm.processing || !canSavePassword"
              class="btn-primary"
            >
              {{ pwForm.processing ? "Salvando..." : "Alterar senha" }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { ref, computed } from "vue";
import { useForm, router } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";
import UserAvatar from "@/components/Shared/UserAvatar.vue";

const props = defineProps({ user: Object });

const uploading = ref(false);
const fileInput = ref(null);

// ─── Info form ─────────────────────────────────
const infoForm = useForm({
  name: props.user.name || "",
});

const saveInfo = () => {
  infoForm.put("/profile", {
    preserveScroll: true,
  });
};

// ─── Avatar upload ─────────────────────────────
const uploadAvatar = async (e) => {
  const file = e.target.files[0];
  if (!file) return;

  if (file.size > 5 * 1024 * 1024) {
    alert("Arquivo muito grande. Máximo 5MB.");
    return;
  }

  if (!["image/jpeg", "image/png", "image/webp"].includes(file.type)) {
    alert("Formato inválido. Use JPG, PNG ou WebP.");
    return;
  }

  uploading.value = true;

  const formData = new FormData();
  formData.append("avatar", file);
  formData.append("name", props.user.name || "");
  formData.append("_method", "PUT");

  try {
    await fetch("/profile", {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
          ?.content,
      },
      body: formData,
    });
    router.reload();
  } finally {
    uploading.value = false;
    if (fileInput.value) fileInput.value.value = "";
  }
};

const removeAvatar = () => {
  if (window.confirm("Remover foto de perfil?")) {
    router.delete("/profile/destroy_avatar", { preserveScroll: true });
  }
};

// ─── Password form ─────────────────────────────
const pwForm = useForm({
  section: "password",
  current_password: "",
  password: "",
  password_confirmation: "",
});

const canSavePassword = computed(
  () =>
    pwForm.current_password &&
    pwForm.password &&
    pwForm.password.length >= 8 &&
    pwForm.password === pwForm.password_confirmation,
);

const savePassword = () => {
  pwForm.put("/profile", {
    preserveScroll: true,
    onSuccess: () => {
      pwForm.reset("current_password", "password", "password_confirmation");
    },
  });
};

// ─── Password strength ─────────────────────────
const passwordStrength = computed(() => {
  const pw = pwForm.password;
  if (!pw) return 0;
  let score = 0;
  if (pw.length >= 8) score++;
  if (pw.length >= 12) score++;
  if (/[A-Z]/.test(pw) && /[a-z]/.test(pw)) score++;
  if (/[0-9]/.test(pw) && /[^a-zA-Z0-9]/.test(pw)) score++;
  return score;
});

const strengthColor = computed(
  () =>
    ({
      1: "bg-red-400",
      2: "bg-amber-400",
      3: "bg-blue-400",
      4: "bg-green-400",
    })[passwordStrength.value] || "bg-gray-200",
);

const strengthTextColor = computed(
  () =>
    ({
      1: "text-red-500",
      2: "text-amber-500",
      3: "text-blue-500",
      4: "text-green-500",
    })[passwordStrength.value] || "text-gray-400",
);

const strengthLabel = computed(
  () =>
    ({
      1: "Fraca",
      2: "Razoável",
      3: "Boa",
      4: "Forte",
    })[passwordStrength.value] || "",
);
</script>

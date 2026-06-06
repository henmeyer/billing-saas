<template>
  <AppLayout>
    <div class="page-header">
      <div>
        <h2 class="page-title">API Keys</h2>
        <p class="text-sm text-gray-500 mt-0.5">Para integrar seu software com a plataforma</p>
      </div>
    </div>

    <!-- Criar nova key -->
    <div class="card mb-6 max-w-md">
      <div class="card-header">
        <h3 class="text-sm font-medium text-gray-900">Nova chave</h3>
      </div>
      <div class="card-body">
        <form @submit.prevent="createKey" class="flex gap-3">
          <input
            v-model="newKeyName"
            type="text"
            placeholder="Nome da chave (ex: Produção)"
            class="form-input flex-1"
            required
          />
          <button type="submit" :disabled="creating" class="btn-primary">
            {{ creating ? "..." : "Gerar" }}
          </button>
        </form>
      </div>
    </div>

    <!-- Lista -->
    <div class="card">
      <div class="table-wrapper">
        <table class="table">
          <thead>
            <tr>
              <th>Nome</th>
              <th>Token</th>
              <th>Último uso</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="!api_keys.length">
              <td colspan="5" class="text-center text-gray-400 py-8">
                Nenhuma chave criada ainda
              </td>
            </tr>
            <tr v-for="key in api_keys" :key="key.id">
              <td class="font-medium">{{ key.name }}</td>
              <td>
                <code class="text-xs bg-gray-100 px-2 py-0.5 rounded">···{{ key.last_four }}</code>
              </td>
              <td class="text-gray-500 text-sm">{{ key.last_used_at }}</td>
              <td>
                <Badge :variant="key.active ? 'green' : 'gray'">
                  {{ key.active ? "Ativa" : "Revogada" }}
                </Badge>
              </td>
              <td class="text-right">
                <ConfirmButton
                  v-if="key.active"
                  :message="`Revogar a chave ${key.name}? Integrações que usam ela vão parar de funcionar.`"
                  @confirm="revokeKey(key.id)"
                >
                  Revogar
                </ConfirmButton>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Exemplo de uso -->
    <div class="card mt-6 max-w-2xl">
      <div class="card-header">
        <h3 class="text-sm font-medium text-gray-900">Como usar</h3>
      </div>
      <div class="card-body space-y-3">
        <p class="text-sm text-gray-600">Inclua o token no header de cada requisição:</p>
        <pre class="bg-gray-900 text-gray-100 rounded-lg p-4 text-xs overflow-x-auto">curl -H "Authorization: Bearer billing_seu_token" \
     /api/v1/customers/EXT123/credits</pre>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { ref } from "vue";
import { router } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";
import Badge from "@/components/Shared/Badge.vue";
import ConfirmButton from "@/components/Shared/ConfirmButton.vue";

defineProps({ api_keys: Array });

const newKeyName = ref("");
const creating = ref(false);

const createKey = () => {
  creating.value = true;
  router.post(
    "/api_keys",
    { name: newKeyName.value },
    {
      onFinish: () => {
        creating.value = false;
        newKeyName.value = "";
      },
    },
  );
};

const revokeKey = (id) => router.delete(`/api_keys/${id}`);
</script>

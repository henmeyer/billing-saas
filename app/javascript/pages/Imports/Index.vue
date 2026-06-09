<template>
  <AppLayout>
    <div class="page-header">
      <div>
        <h2 class="page-title">Importar clientes</h2>
        <p class="text-sm text-gray-500 mt-0.5">
          Importe clientes e assinaturas ativas do Asaas ou Stripe
        </p>
      </div>
    </div>

    <!-- Nova importação -->
    <div class="card mb-6 max-w-md">
      <div class="card-header">
        <h3 class="text-sm font-medium text-gray-900">Nova importação</h3>
      </div>
      <div class="card-body space-y-4">
        <div>
          <label class="form-label">Gateway de origem</label>
          <select v-model="selectedGateway" class="form-input">
            <option value="">Selecione</option>
            <option v-for="g in gateways" :key="g" :value="g">
              {{ gatewayLabel(g) }}
            </option>
          </select>
        </div>

        <div v-if="selectedGateway" class="alert-info text-xs">
          <span>ℹ</span>
          <span>
            Serão importados todos os clientes com assinatura ativa no
            {{ gatewayLabel(selectedGateway) }}. Você poderá revisar antes de
            confirmar.
          </span>
        </div>

        <button
          @click="startImport"
          :disabled="!selectedGateway || starting"
          class="btn-primary w-full justify-center"
        >
          {{ starting ? "Iniciando..." : "Buscar clientes" }}
        </button>
      </div>
    </div>

    <!-- Histórico -->
    <div v-if="importJobs.length" class="card">
      <div class="card-header">
        <h3 class="text-sm font-medium text-gray-900">Histórico</h3>
      </div>
      <div class="table-wrapper border-0 rounded-none">
        <table class="table">
          <thead>
            <tr>
              <th>Gateway</th>
              <th>Status</th>
              <th>Clientes</th>
              <th>Resultado</th>
              <th>Data</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="job in importJobs" :key="job.id">
              <td>
                <Badge variant="gray">{{ gatewayLabel(job.gateway) }}</Badge>
              </td>
              <td>
                <Badge :variant="statusVariant(job.status)">
                  {{ statusLabel(job.status) }}
                </Badge>
              </td>
              <td class="text-sm text-gray-600">
                <span v-if="job.total_preview > 0">
                  {{ job.total_preview }} encontrados
                </span>
                <span v-else class="text-gray-400">—</span>
              </td>
              <td class="text-sm">
                <span v-if="job.result?.imported" class="text-green-600">
                  {{ job.result.imported }} importados
                </span>
                <span v-if="job.result?.updated" class="text-blue-600 ml-2">
                  {{ job.result.updated }} atualizados
                </span>
                <span v-if="job.result?.skipped" class="text-gray-400 ml-2">
                  {{ job.result.skipped }} ignorados
                </span>
                <span
                  v-if="!job.result?.imported && !job.result?.updated"
                  class="text-gray-400"
                  >—</span
                >
              </td>
              <td class="text-gray-500 text-sm">{{ job.created_at }}</td>
              <td class="text-right">
                <Link :href="`/imports/${job.id}`" class="btn-secondary btn-sm">
                  Ver
                </Link>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { ref } from "vue";
import { Link, router } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";
import Badge from "@/components/Shared/Badge.vue";

defineProps({
  importJobs: { type: Array, default: () => [] },
  gateways: { type: Array, default: () => [] },
});

const selectedGateway = ref("");
const starting = ref(false);

const startImport = () => {
  if (!selectedGateway.value) return;
  starting.value = true;
  router.post(
    "/imports",
    { gateway: selectedGateway.value },
    { onFinish: () => { starting.value = false; } }
  );
};

const gatewayLabel = (g) =>
  ({ asaas: "Asaas", stripe: "Stripe", dlocal_go: "dLocal Go" })[g] || g;

const statusVariant = (s) =>
  ({
    pending:       "gray",
    fetching:      "yellow",
    preview_ready: "blue",
    importing:     "yellow",
    done:          "green",
    failed:        "red",
  })[s] || "gray";

const statusLabel = (s) =>
  ({
    pending:       "Aguardando",
    fetching:      "Buscando...",
    preview_ready: "Aguardando revisão",
    importing:     "Importando...",
    done:          "Concluído",
    failed:        "Erro",
  })[s] || s;
</script>

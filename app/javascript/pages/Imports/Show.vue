<template>
  <AppLayout>
    <div class="page-header">
      <div class="flex items-center gap-3">
        <Link href="/imports" class="text-sm text-gray-500 hover:text-gray-700">
          ← Importações
        </Link>
        <h2 class="page-title">
          Importar do {{ gatewayLabel(import_job.gateway) }}
        </h2>
        <Badge :variant="statusVariant(import_job.status)">
          {{ statusLabel(import_job.status) }}
        </Badge>
      </div>
    </div>

    <!-- Buscando -->
    <div v-if="import_job.status === 'fetching'" class="card">
      <div class="card-body text-center py-12">
        <div class="flex justify-center mb-4">
          <svg
            class="animate-spin h-8 w-8 text-brand-500"
            viewBox="0 0 24 24"
            fill="none"
          >
            <circle
              class="opacity-25"
              cx="12"
              cy="12"
              r="10"
              stroke="currentColor"
              stroke-width="4"
            />
            <path
              class="opacity-75"
              fill="currentColor"
              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
            />
          </svg>
        </div>
        <p class="text-gray-600 font-medium">
          Buscando clientes no {{ gatewayLabel(import_job.gateway) }}...
        </p>
        <p class="text-sm text-gray-400 mt-1">
          Isso pode levar alguns segundos dependendo do volume.
        </p>
      </div>
    </div>

    <!-- Pendente -->
    <div v-else-if="import_job.status === 'pending'" class="card">
      <div class="card-body text-center py-12">
        <p class="text-gray-500">Preparando importação...</p>
      </div>
    </div>

    <!-- Erro -->
    <div v-else-if="import_job.status === 'failed'" class="alert-danger">
      <span>✕</span>
      <div>
        <p class="font-medium">Erro na importação</p>
        <p class="text-xs mt-1">{{ import_job.error_message }}</p>
      </div>
    </div>

    <!-- Concluído -->
    <div v-else-if="import_job.status === 'done'" class="space-y-4">
      <div class="card">
        <div class="card-body">
          <p class="text-sm font-medium text-gray-900 mb-4">
            Importação concluída
          </p>
          <div class="grid grid-cols-3 gap-4">
            <div class="text-center">
              <p class="text-2xl font-semibold text-green-600">
                {{ import_job.result?.imported || 0 }}
              </p>
              <p class="text-xs text-gray-500">Importados</p>
            </div>
            <div class="text-center">
              <p class="text-2xl font-semibold text-blue-600">
                {{ import_job.result?.updated || 0 }}
              </p>
              <p class="text-xs text-gray-500">Atualizados</p>
            </div>
            <div class="text-center">
              <p class="text-2xl font-semibold text-gray-400">
                {{ import_job.result?.skipped || 0 }}
              </p>
              <p class="text-xs text-gray-500">Ignorados</p>
            </div>
          </div>
        </div>
      </div>

      <div v-if="import_job.result?.errors?.length" class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-red-600">
            {{ import_job.result.errors.length }} erro(s)
          </h3>
        </div>
        <div class="divide-y divide-gray-100">
          <div
            v-for="err in import_job.result.errors"
            :key="err.email"
            class="px-6 py-3"
          >
            <p class="text-sm font-medium text-gray-900">{{ err.email }}</p>
            <p class="text-xs text-red-600">{{ err.message }}</p>
          </div>
        </div>
      </div>

      <Link href="/customers" class="btn-primary inline-flex">
        Ver clientes importados →
      </Link>
    </div>

    <!-- Preview pronto / importando -->
    <div
      v-else-if="['preview_ready', 'importing'].includes(import_job.status)"
      class="space-y-6"
    >
      <!-- Resumo -->
      <div class="grid grid-cols-2 gap-4">
        <div class="card text-center py-4">
          <p class="text-2xl font-semibold text-green-600">
            {{ import_job.total_new }}
          </p>
          <p class="text-sm text-gray-500">Novos clientes</p>
        </div>
        <div class="card text-center py-4">
          <p class="text-2xl font-semibold text-amber-500">
            {{ import_job.total_duplicates }}
          </p>
          <p class="text-sm text-gray-500">Duplicatas encontradas</p>
        </div>
      </div>

      <!-- Novos clientes -->
      <div v-if="import_job.preview?.new?.length" class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">
            Novos clientes ({{ import_job.preview.new.length }})
          </h3>
          <p class="text-xs text-gray-500 mt-0.5">
            Serão criados automaticamente.
          </p>
        </div>
        <div class="table-wrapper border-0 rounded-none max-h-64 overflow-y-auto">
          <table class="table">
            <thead>
              <tr>
                <th>Cliente</th>
                <th>Assinatura</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="c in import_job.preview.new"
                :key="c.email || c.gateway_id"
              >
                <td>
                  <p class="font-medium text-gray-900">{{ c.name }}</p>
                  <p class="text-xs text-gray-400">{{ c.email }}</p>
                </td>
                <td>
                  <Badge v-if="c.subscription" variant="green">Ativa</Badge>
                  <span v-else class="text-xs text-gray-400">Sem assinatura</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Duplicatas -->
      <div v-if="import_job.preview?.duplicates?.length" class="card">
        <div class="card-header">
          <div class="flex items-center justify-between">
            <div>
              <h3 class="text-sm font-medium text-gray-900">
                Duplicatas ({{ import_job.preview.duplicates.length }})
              </h3>
              <p class="text-xs text-gray-500 mt-0.5">
                Estes emails já existem. Escolha o que fazer com cada um.
              </p>
            </div>
            <div class="flex gap-2">
              <button @click="setAllDecisions('skip')" class="btn-secondary btn-sm">
                Ignorar todos
              </button>
              <button @click="setAllDecisions('update')" class="btn-secondary btn-sm">
                Atualizar todos
              </button>
            </div>
          </div>
        </div>
        <div class="divide-y divide-gray-100">
          <div
            v-for="c in import_job.preview.duplicates"
            :key="c.email"
            class="px-6 py-4 flex items-center gap-4"
          >
            <div class="flex-1">
              <p class="text-sm font-medium text-gray-900">{{ c.name }}</p>
              <p class="text-xs text-gray-400">{{ c.email }}</p>
            </div>
            <div class="flex gap-2">
              <button
                v-for="opt in decisionOptions"
                :key="opt.value"
                @click="setDecision(c.email, opt.value)"
                :class="[
                  'px-3 py-1.5 text-xs rounded-lg border font-medium transition-colors',
                  decisions[c.email] === opt.value
                    ? opt.activeClass
                    : 'border-gray-200 text-gray-500 hover:border-gray-300',
                ]"
              >
                {{ opt.label }}
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Confirmar -->
      <div class="flex items-center justify-between">
        <p class="text-sm text-gray-500">
          <span v-if="undecidedCount > 0" class="text-amber-600">
            ⚠ {{ undecidedCount }} duplicata(s) sem decisão — serão ignoradas por padrão.
          </span>
          <span v-else class="text-green-600">✓ Tudo pronto para importar</span>
        </p>

        <button
          @click="executeImport"
          :disabled="executing || import_job.status === 'importing'"
          class="btn-primary"
        >
          <span v-if="executing || import_job.status === 'importing'">
            Importando...
          </span>
          <span v-else>
            Confirmar importação ({{ import_job.total_new + decidedCount }} clientes)
          </span>
        </button>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from "vue";
import { Link, router } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";
import Badge from "@/components/Shared/Badge.vue";

const props = defineProps({ import_job: Object });

const decisions = ref({ ...props.import_job.decisions });
const executing = ref(false);
let polling = null;
let mounted = true;

const decisionOptions = [
  { value: "skip",   label: "Ignorar",   activeClass: "border-gray-400 bg-gray-100 text-gray-700" },
  { value: "update", label: "Atualizar", activeClass: "border-blue-400 bg-blue-50 text-blue-700" },
  { value: "create", label: "Criar novo", activeClass: "border-green-400 bg-green-50 text-green-700" },
];

const setDecision = (email, value) => {
  decisions.value[email] = value;
  saveDecisions();
};

const setAllDecisions = (value) => {
  (props.import_job.preview?.duplicates || []).forEach((c) => {
    decisions.value[c.email] = value;
  });
  saveDecisions();
};

const saveDecisions = async () => {
  await fetch(`/imports/${props.import_job.id}/decide`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
    },
    body: JSON.stringify({ decisions: decisions.value }),
  });
};

const executeImport = () => {
  executing.value = true;
  fetch(`/imports/${props.import_job.id}/execute`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
    },
  });
  startPolling();
};

const startPolling = () => {
  if (polling) return;
  polling = setInterval(() => {
    router.reload({ only: ["import_job"] });
  }, 2000);
};

const stopPolling = () => {
  if (polling) {
    clearInterval(polling);
    polling = null;
  }
};

watch(
  () => props.import_job.status,
  (status) => {
    if (["done", "failed"].includes(status)) stopPolling();
  },
);

const undecidedCount = computed(() => {
  const dups = props.import_job.preview?.duplicates || [];
  return dups.filter((c) => !decisions.value[c.email]).length;
});

const decidedCount = computed(() => {
  const dups = props.import_job.preview?.duplicates || [];
  return dups.filter((c) => {
    const d = decisions.value[c.email];
    return d === "update" || d === "create";
  }).length;
});

const gatewayLabel = (g) => ({ asaas: "Asaas", stripe: "Stripe", dlocal_go: "dLocal Go" })[g] || g;

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

onMounted(() => {
  if (["fetching", "pending", "importing"].includes(props.import_job.status)) {
    startPolling();
  }
});

onUnmounted(() => {
  mounted = false;
  stopPolling();
});
</script>

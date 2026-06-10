<template>
  <AppLayout>
    <div class="page-header">
      <div class="flex items-center gap-3">
        <Link href="/integrations" class="text-sm text-gray-500 hover:text-gray-700">
          ← Integrações
        </Link>
        <h2 class="page-title">{{ integration.name }}</h2>
        <Badge :variant="integration.active ? 'green' : 'gray'">
          {{ integration.active ? "Ativa" : "Inativa" }}
        </Badge>
      </div>
      <Link :href="`/integrations/${integration.id}/edit`" class="btn-secondary">
        Editar
      </Link>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
      <!-- API Keys -->
      <div class="lg:col-span-2">
        <div class="card">
          <div class="card-header flex items-center justify-between">
            <div>
              <h3 class="text-sm font-medium text-gray-900">API Keys</h3>
              <p class="text-xs text-gray-500 mt-0.5">
                Use estas chaves para integrar seu software com a plataforma.
                <strong>Não use API Keys de conta aqui.</strong>
              </p>
            </div>
            <button @click="showNewKeyForm = !showNewKeyForm" class="btn-secondary btn-sm">
              + Nova chave
            </button>
          </div>

          <!-- Form de nova chave -->
          <div v-if="showNewKeyForm" class="px-6 py-4 border-b border-gray-100">
            <form @submit.prevent="createKey" class="flex gap-3">
              <input
                v-model="createForm.name"
                type="text"
                class="form-input flex-1"
                placeholder="Nome da chave (ex: Produção)"
                required
              />
              <button type="submit" :disabled="createForm.processing" class="btn-primary">
                {{ createForm.processing ? "..." : "Gerar" }}
              </button>
            </form>
          </div>

          <!-- Token gerado (mostrado uma vez) -->
          <div v-if="newToken" class="px-6 py-4 border-b border-yellow-100 bg-yellow-50">
            <p class="text-xs font-medium text-yellow-800 mb-1">
              Copie agora — não será exibido novamente
            </p>
            <code class="text-xs font-mono text-yellow-900 break-all block bg-yellow-100 px-3 py-2 rounded">
              {{ newToken }}
            </code>
            <button @click="newToken = null" class="text-xs text-yellow-600 mt-2">Fechar</button>
          </div>

          <!-- Lista de chaves -->
          <div v-if="!localApiKeys.length" class="px-6 py-8 text-center text-sm text-gray-400">
            Nenhuma API Key criada para esta integração.
          </div>
          <div v-else class="divide-y divide-gray-100">
            <div
              v-for="key in localApiKeys"
              :key="key.id"
              class="px-6 py-3 flex items-center justify-between"
            >
              <div>
                <p class="text-sm font-medium text-gray-900">{{ key.name }}</p>
                <div class="flex items-center gap-3 mt-0.5">
                  <code class="text-xs bg-gray-100 px-2 py-0.5 rounded font-mono">
                    billing_int_···{{ key.last_four }}
                  </code>
                  <span class="text-xs text-gray-400">{{ key.last_used_at }}</span>
                </div>
              </div>
              <div class="flex items-center gap-2">
                <Badge :variant="key.active ? 'green' : 'gray'">
                  {{ key.active ? "Ativa" : "Revogada" }}
                </Badge>
                <ConfirmButton
                  v-if="key.active"
                  :message="`Revogar a chave ${key.name}?`"
                  @confirm="revokeKey(key.id)"
                >
                  Revogar
                </ConfirmButton>
              </div>
            </div>
          </div>

          <!-- Instruções de uso -->
          <div class="px-6 py-4 bg-gray-50 rounded-b-xl">
            <p class="text-xs font-medium text-gray-500 mb-2">Como usar</p>
            <pre class="text-xs bg-gray-900 text-gray-100 rounded px-3 py-2 overflow-x-auto">curl -H "Authorization: Bearer billing_int_sua_chave" \
     {{ appUrl }}/api/v1/customers/EXT123/credits</pre>
          </div>
        </div>
      </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <!-- Info da integração -->
      <div class="space-y-4">
        <div class="card">
          <div class="card-header">
            <h3 class="text-sm font-medium text-gray-900">Configuração</h3>
          </div>
          <div class="card-body space-y-3">
            <div>
              <p class="text-xs text-gray-500">URL</p>
              <p class="text-sm font-mono text-gray-900 break-all">{{ integration.url }}</p>
            </div>
            <div>
              <p class="text-xs text-gray-500">Secret (para validar assinatura)</p>
              <div class="flex items-center gap-2">
                <code class="text-xs bg-gray-100 px-2 py-1 rounded flex-1 font-mono">
                  {{ showSecret ? integration.secret : "••••••••••••••••" }}
                </code>
                <button
                  @click="showSecret = !showSecret"
                  class="text-xs text-gray-400 hover:text-gray-600"
                >
                  {{ showSecret ? "Ocultar" : "Revelar" }}
                </button>
              </div>
            </div>
            <div>
              <p class="text-xs text-gray-500">Eventos</p>
              <div class="flex flex-wrap gap-1.5 mt-1">
                <Badge v-for="event in integration.events" :key="event" variant="blue">
                  {{ event }}
                </Badge>
              </div>
            </div>
          </div>
        </div>

        <!-- Instruções de validação -->
        <div class="card bg-gray-50">
          <div class="card-header">
            <h3 class="text-sm font-medium text-gray-900">Como validar a assinatura</h3>
          </div>
          <div class="card-body">
            <p class="text-xs text-gray-600 mb-3">
              Cada webhook inclui o header
              <code class="bg-gray-200 px-1 rounded">X-Billing-Signature</code>.
              Valide assim:
            </p>
            <pre class="bg-gray-900 text-gray-100 rounded-lg p-3 text-xs overflow-x-auto">
# Ruby
expected = "sha256=" + OpenSSL::HMAC.hexdigest(
  "SHA256", SECRET, request.body.read
)
valid = ActiveSupport::SecurityUtils.secure_compare(
  expected, request.headers["X-Billing-Signature"]
)

# Node.js
const sig = crypto
  .createHmac('sha256', SECRET)
  .update(rawBody)
  .digest('hex')
const valid = `sha256=${sig}` === req.headers['x-billing-signature']

# Python
import hmac, hashlib
sig = hmac.new(SECRET.encode(), raw_body, hashlib.sha256).hexdigest()
valid = f"sha256={sig}" == request.headers.get("X-Billing-Signature")</pre>
          </div>
        </div>
      </div>

      <!-- Teste de webhook -->
      <div class="space-y-4">
        <div class="card">
          <div class="card-header">
            <h3 class="text-sm font-medium text-gray-900">Testar webhook</h3>
            <p class="text-xs text-gray-500 mt-0.5">
              Dispara um payload de teste para a URL configurada. O payload
              inclui <code class="bg-gray-100 px-1 rounded">test: true</code>.
            </p>
          </div>
          <div class="card-body space-y-4">
            <div>
              <label class="form-label">Evento a testar</label>
              <select v-model="selectedEvent" class="form-input">
                <option
                  v-for="event in integration.events"
                  :key="event"
                  :value="event"
                >
                  {{ event }}
                </option>
              </select>
            </div>

            <button
              @click="sendTest"
              :disabled="testing || !selectedEvent"
              class="btn-primary w-full justify-center"
            >
              <span v-if="testing" class="flex items-center gap-2">
                <svg class="animate-spin h-4 w-4" viewBox="0 0 24 24" fill="none">
                  <circle
                    class="opacity-25"
                    cx="12" cy="12" r="10"
                    stroke="currentColor"
                    stroke-width="4"
                  />
                  <path
                    class="opacity-75"
                    fill="currentColor"
                    d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
                  />
                </svg>
                Enviando...
              </span>
              <span v-else>Disparar teste</span>
            </button>

            <!-- Resultado do teste -->
            <div v-if="lastResult" class="rounded-lg border overflow-hidden">
              <div
                :class="[
                  'px-4 py-2.5 flex items-center justify-between',
                  lastResult.success
                    ? 'bg-green-50 border-b border-green-200'
                    : 'bg-red-50 border-b border-red-200',
                ]"
              >
                <div class="flex items-center gap-2">
                  <span>{{ lastResult.success ? "✓" : "✕" }}</span>
                  <span
                    :class="[
                      'text-sm font-medium',
                      lastResult.success ? 'text-green-800' : 'text-red-800',
                    ]"
                  >
                    {{ lastResult.success ? "Entregue com sucesso" : "Falha na entrega" }}
                  </span>
                </div>
                <div class="flex items-center gap-3 text-xs text-gray-500">
                  <span v-if="lastResult.status_code">HTTP {{ lastResult.status_code }}</span>
                  <span>{{ lastResult.duration_ms }}ms</span>
                </div>
              </div>

              <div
                v-if="lastResult.error"
                class="px-4 py-3 bg-red-50 text-xs text-red-700 font-mono"
              >
                {{ lastResult.error }}
              </div>

              <div v-if="lastResult.response_body" class="px-4 py-3 bg-gray-50">
                <p class="text-xs text-gray-500 mb-1">Resposta do servidor:</p>
                <pre class="text-xs text-gray-700 font-mono whitespace-pre-wrap break-all">{{ lastResult.response_body }}</pre>
              </div>
            </div>
          </div>
        </div>

        <!-- Histórico de testes -->
        <div class="card">
          <div class="card-header flex items-center justify-between">
            <h3 class="text-sm font-medium text-gray-900">Histórico de testes</h3>
            <button @click="loadLogs" class="text-xs text-brand-600 hover:text-brand-700">
              Atualizar
            </button>
          </div>
          <div
            v-if="!testLogs.length"
            class="card-body text-center text-sm text-gray-400 py-6"
          >
            Nenhum teste realizado ainda.
          </div>
          <div v-else class="divide-y divide-gray-100">
            <div
              v-for="log in testLogs"
              :key="log.id"
              class="px-6 py-3 flex items-center justify-between"
            >
              <div>
                <div class="flex items-center gap-2">
                  <span
                    :class="[
                      'w-2 h-2 rounded-full flex-shrink-0',
                      log.status === 'delivered' ? 'bg-green-400' : 'bg-red-400',
                    ]"
                  />
                  <span class="text-sm font-mono text-gray-700">{{ log.event }}</span>
                </div>
                <p class="text-xs text-gray-400 mt-0.5 ml-4">{{ log.created_at }}</p>
              </div>
              <div class="text-right text-xs text-gray-500">
                <p v-if="log.status_code">HTTP {{ log.status_code }}</p>
                <p>{{ log.duration_ms }}ms</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { Link, router, useForm, usePage } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";
import Badge from "@/components/Shared/Badge.vue";
import ConfirmButton from "@/components/Shared/ConfirmButton.vue";

const props = defineProps({
  integration: Object,
  apiKeys: { type: Array, default: () => [] },
});

const page = usePage();

const selectedEvent = ref(props.integration.events?.[0] || "");
const testing = ref(false);
const showSecret = ref(false);
const lastResult = ref(null);
const testLogs = ref([]);

// API Keys
const showNewKeyForm = ref(false);
const localApiKeys = ref(props.apiKeys);
const appUrl = window.location.origin;

const newToken = ref(page.props.flash?.token || null);

const createForm = useForm({ name: "" });

const createKey = () => {
  createForm.post(`/integrations/${props.integration.id}/integration_api_keys`, {
    onSuccess: () => {
      showNewKeyForm.value = false;
      createForm.reset();
      newToken.value = page.props.flash?.token || null;
    },
  });
};

const revokeKey = (id) => {
  router.delete(`/integrations/${props.integration.id}/integration_api_keys/${id}`, {
    onSuccess: () => {
      const key = localApiKeys.value.find((k) => k.id === id);
      if (key) key.active = false;
    },
  });
};

const sendTest = async () => {
  if (!selectedEvent.value || testing.value) return;

  testing.value = true;
  lastResult.value = null;

  try {
    const response = await fetch(
      `/integrations/${props.integration.id}/webhook_tests`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
        },
        body: JSON.stringify({ event: selectedEvent.value }),
      },
    );

    lastResult.value = await response.json();
    await loadLogs();
  } catch (e) {
    lastResult.value = {
      success: false,
      error: `Erro de rede: ${e.message}`,
      status_code: null,
      response_body: null,
      duration_ms: 0,
    };
  } finally {
    testing.value = false;
  }
};

const loadLogs = async () => {
  try {
    const response = await fetch(
      `/integrations/${props.integration.id}/webhook_tests/logs`,
    );
    const data = await response.json();
    testLogs.value = data.logs;
  } catch (e) {
    console.error("Erro ao carregar logs:", e);
  }
};

onMounted(loadLogs);
</script>

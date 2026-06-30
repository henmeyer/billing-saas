<template>
  <AppLayout>
    <div class="page-header">
      <div class="flex items-center gap-3">
        <Link
          href="/integrations"
          class="text-sm text-gray-500 hover:text-gray-700"
        >
          ← Integrações
        </Link>
        <h2 class="page-title">{{ integration.name }}</h2>
        <Badge :variant="integration.active ? 'green' : 'gray'">
          {{ integration.active ? "Ativa" : "Inativa" }}
        </Badge>
      </div>
      <Link
        :href="`/integrations/${integration.id}/edit`"
        class="btn-secondary"
      >
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
            <button
              @click="showNewKeyForm = !showNewKeyForm"
              class="btn-secondary btn-sm"
            >
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
              <button
                type="submit"
                :disabled="createForm.processing"
                class="btn-primary"
              >
                {{ createForm.processing ? "..." : "Gerar" }}
              </button>
            </form>
          </div>

          <!-- Token gerado (mostrado uma vez) -->
          <div
            v-if="newToken"
            class="px-6 py-4 border-b border-yellow-100 bg-yellow-50"
          >
            <p class="text-xs font-medium text-yellow-800 mb-1">
              Copie agora — não será exibido novamente
            </p>
            <code
              class="text-xs font-mono text-yellow-900 break-all block bg-yellow-100 px-3 py-2 rounded"
            >
              {{ newToken }}
            </code>
            <button
              @click="newToken = null"
              class="text-xs text-yellow-600 mt-2"
            >
              Fechar
            </button>
          </div>

          <!-- Lista de chaves -->
          <div
            v-if="!localApiKeys.length"
            class="px-6 py-8 text-center text-sm text-gray-400"
          >
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
                  <code
                    class="text-xs bg-gray-100 px-2 py-0.5 rounded font-mono"
                  >
                    billing_int_···{{ key.last_four }}
                  </code>
                  <span class="text-xs text-gray-400">{{
                    key.last_used_at
                  }}</span>
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
            <pre
              class="text-xs bg-gray-900 text-gray-100 rounded px-3 py-2 overflow-x-auto"
            >
curl -H "Authorization: Bearer billing_int_sua_chave" \
     {{ appUrl }}/api/v1/customers/EXT123/credits</pre
            >
          </div>
        </div>
      </div>
    </div>

    <!-- Portal do cliente -->
    <div class="card mb-6">
      <div class="card-header flex items-center justify-between">
        <div>
          <h3 class="text-sm font-medium text-gray-900">Portal do cliente</h3>
          <p class="text-xs text-gray-500 mt-0.5">
            Configurações do portal de autoatendimento para clientes desta
            integração.
          </p>
        </div>
        <button
          @click="showPortalPreview = !showPortalPreview"
          class="btn-secondary btn-sm"
        >
          {{ showPortalPreview ? "Fechar preview" : "Preview do portal" }}
        </button>
      </div>
      <div class="card-body">
        <div class="grid grid-cols-2 md:grid-cols-3 gap-4 mb-4">
          <div>
            <p class="text-xs text-gray-500">Cor principal</p>
            <div class="flex items-center gap-2 mt-1">
              <span
                class="w-5 h-5 rounded-full border border-gray-200"
                :style="{
                  backgroundColor:
                    integration.portal_primary_color || '#6366f1',
                }"
              />
              <span class="text-sm font-mono text-gray-700">
                {{ integration.portal_primary_color || "#6366f1" }}
              </span>
            </div>
          </div>
          <div>
            <p class="text-xs text-gray-500">Logo</p>
            <p class="text-sm text-gray-700 mt-1">
              {{
                integration.portal_logo_url ? "Configurado" : "Não configurado"
              }}
            </p>
          </div>
        </div>
        <div class="grid grid-cols-2 md:grid-cols-3 gap-3">
          <div
            v-for="opt in portalOptions"
            :key="opt.key"
            class="flex items-center gap-2"
          >
            <span
              :class="[
                'w-4 h-4 rounded-full flex items-center justify-center text-xs',
                portalConfig[opt.key]
                  ? 'bg-green-100 text-green-600'
                  : 'bg-gray-100 text-gray-400',
              ]"
            >
              {{ portalConfig[opt.key] ? "✓" : "✕" }}
            </span>
            <span class="text-sm text-gray-700">{{ opt.label }}</span>
          </div>
        </div>
      </div>

      <!-- Portal Preview -->
      <div v-if="showPortalPreview" class="border-t border-gray-200">
        <div class="p-4">
          <p
            class="text-xs text-gray-500 mb-3 font-medium uppercase tracking-wider"
          >
            Preview do portal
          </p>
          <div
            class="border border-gray-200 rounded-xl overflow-hidden shadow-sm"
            :style="{
              '--portal-primary': integration.portal_primary_color || '#6366f1',
            }"
          >
            <!-- Header preview -->
            <div
              class="bg-white border-b border-gray-200 px-4 py-3 flex items-center justify-between"
            >
              <div class="flex items-center gap-3">
                <img
                  v-if="integration.portal_logo_url"
                  :src="integration.portal_logo_url"
                  class="h-6 object-contain"
                  :alt="integration.name"
                />
                <span v-else class="text-sm font-semibold text-gray-900">
                  {{ integration.name }}
                </span>
              </div>
              <div class="flex items-center gap-1">
                <span
                  class="px-2.5 py-1 text-xs rounded-lg bg-gray-100 text-gray-900 font-medium"
                  >Meu plano</span
                >
                <span
                  v-if="portalConfig.allow_plan_change"
                  class="px-2.5 py-1 text-xs rounded-lg text-gray-500"
                  >Planos</span
                >
                <span
                  v-if="portalConfig.allow_buy_products"
                  class="px-2.5 py-1 text-xs rounded-lg text-gray-500"
                  >Comprar</span
                >
                <span
                  v-if="portalConfig.show_invoice_history"
                  class="px-2.5 py-1 text-xs rounded-lg text-gray-500"
                  >Faturas</span
                >
              </div>
              <span class="text-xs text-gray-400">cliente@exemplo.com</span>
            </div>

            <!-- Content preview -->
            <div class="bg-gray-50 p-4">
              <div class="grid grid-cols-3 gap-3">
                <!-- Plano card -->
                <div
                  class="col-span-2 bg-white rounded-lg border border-gray-200 p-3"
                >
                  <div class="flex items-center justify-between mb-2">
                    <span class="text-sm font-semibold text-gray-900"
                      >Plano Exemplo</span
                    >
                    <span
                      class="text-xs bg-green-100 text-green-700 px-2 py-0.5 rounded-full"
                      >Ativo</span
                    >
                  </div>
                  <div class="bg-gray-50 rounded px-3 py-2 text-xs space-y-1">
                    <div class="flex justify-between">
                      <span class="text-gray-500">Valor base</span
                      ><span>R$ 197,00/mês</span>
                    </div>
                    <div
                      class="flex justify-between font-semibold border-t border-gray-200 pt-1"
                    >
                      <span>Total</span><span>R$ 197,00</span>
                    </div>
                  </div>
                  <div class="mt-2 pt-2 border-t border-gray-100">
                    <!-- Progress bar simulada -->
                    <div class="flex justify-between text-xs mb-1">
                      <span class="text-gray-600">Créditos API</span>
                      <span class="text-gray-400">3.200 / 5.000</span>
                    </div>
                    <div
                      class="w-full h-1.5 bg-gray-200 rounded-full overflow-hidden"
                    >
                      <div
                        class="h-full rounded-full"
                        :style="{
                          width: '64%',
                          backgroundColor:
                            integration.portal_primary_color || '#6366f1',
                        }"
                      />
                    </div>
                  </div>
                  <div class="flex gap-2 mt-3 pt-2 border-t border-gray-100">
                    <span
                      v-if="portalConfig.allow_plan_change"
                      class="text-xs border border-gray-200 rounded-lg px-2 py-1 text-gray-600"
                      >Trocar de plano</span
                    >
                    <span
                      v-if="portalConfig.allow_cancel"
                      class="text-xs border border-red-200 rounded-lg px-2 py-1 text-red-500"
                      >Cancelar</span
                    >
                  </div>
                </div>

                <!-- Sidebar -->
                <div class="space-y-3">
                  <div class="bg-white rounded-lg border border-gray-200 p-3">
                    <p class="text-xs font-medium text-gray-900 mb-1">
                      Recursos
                    </p>
                    <div class="space-y-0.5">
                      <div
                        class="text-xs text-gray-600 flex items-center gap-1"
                      >
                        <span class="text-green-500">✓</span> Feature A
                      </div>
                      <div
                        class="text-xs text-gray-600 flex items-center gap-1"
                      >
                        <span class="text-green-500">✓</span> Feature B
                      </div>
                      <div
                        class="text-xs text-gray-300 flex items-center gap-1"
                      >
                        <span>✕</span> Feature C
                      </div>
                    </div>
                  </div>
                  <div
                    v-if="portalConfig.allow_buy_products"
                    class="bg-white rounded-lg border border-gray-200 p-3 text-center"
                  >
                    <p class="text-xs text-gray-500 mb-1">Precisa de mais?</p>
                    <span
                      class="text-xs text-white rounded-lg px-3 py-1 inline-block"
                      :style="{
                        backgroundColor:
                          integration.portal_primary_color || '#6366f1',
                      }"
                    >
                      Comprar pacotes
                    </span>
                  </div>
                </div>
              </div>
            </div>
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
              <p class="text-sm font-mono text-gray-900 break-all">
                {{ integration.url }}
              </p>
            </div>
            <div>
              <p class="text-xs text-gray-500">
                Secret (para validar assinatura)
              </p>
              <div class="flex items-center gap-2">
                <code
                  class="text-xs bg-gray-100 px-2 py-1 rounded flex-1 font-mono"
                >
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
                <Badge
                  v-for="event in integration.events"
                  :key="event"
                  variant="blue"
                >
                  {{ event }}
                </Badge>
              </div>
            </div>
          </div>
        </div>

        <!-- Instruções de validação -->
        <div class="card bg-gray-50">
          <div class="card-header">
            <h3 class="text-sm font-medium text-gray-900">
              Como validar a assinatura
            </h3>
          </div>
          <div class="card-body">
            <p class="text-xs text-gray-600 mb-3">
              Cada webhook inclui o header
              <code class="bg-gray-200 px-1 rounded">X-Billing-Signature</code>.
              Valide assim:
            </p>
            <pre
              class="bg-gray-900 text-gray-100 rounded-lg p-3 text-xs overflow-x-auto"
            >
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
valid = f"sha256={sig}" == request.headers.get("X-Billing-Signature")</pre
            >
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
                <svg
                  class="animate-spin h-4 w-4"
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
                    {{
                      lastResult.success
                        ? "Entregue com sucesso"
                        : "Falha na entrega"
                    }}
                  </span>
                </div>
                <div class="flex items-center gap-3 text-xs text-gray-500">
                  <span v-if="lastResult.status_code"
                    >HTTP {{ lastResult.status_code }}</span
                  >
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
                <pre
                  class="text-xs text-gray-700 font-mono whitespace-pre-wrap break-all"
                  >{{ lastResult.response_body }}</pre
                >
              </div>
            </div>
          </div>
        </div>

        <!-- Histórico de testes -->
        <div class="card">
          <div class="card-header flex items-center justify-between">
            <h3 class="text-sm font-medium text-gray-900">
              Histórico de testes
            </h3>
            <button
              @click="loadLogs"
              class="text-xs text-brand-600 hover:text-brand-700"
            >
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
                      log.status === 'delivered'
                        ? 'bg-green-400'
                        : 'bg-red-400',
                    ]"
                  />
                  <span class="text-sm font-mono text-gray-700">{{
                    log.event
                  }}</span>
                </div>
                <p class="text-xs text-gray-400 mt-0.5 ml-4">
                  {{ log.created_at }}
                </p>
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

    <!-- Logs completos de webhook -->
    <div class="card mt-6">
      <div class="card-header flex items-center justify-between">
        <div>
          <h3 class="text-sm font-medium text-gray-900">Logs de webhook</h3>
          <p class="text-xs text-gray-500 mt-0.5">
            Todos os webhooks disparados para esta integração.
          </p>
        </div>
        <div class="flex items-center gap-2">
          <select v-model="logFilter" class="form-input text-xs py-1 w-auto">
            <option value="all">Todos</option>
            <option value="delivered">Entregues</option>
            <option value="failed">Falhou</option>
            <option value="pending">Pendentes</option>
          </select>
          <button
            @click="loadAllLogs"
            class="text-xs text-brand-600 hover:text-brand-700"
          >
            Atualizar
          </button>
        </div>
      </div>
      <div
        v-if="!allLogs.length"
        class="card-body text-center text-sm text-gray-400 py-6"
      >
        Nenhum webhook disparado ainda.
      </div>
      <div v-else class="divide-y divide-gray-100 max-h-96 overflow-y-auto">
        <div
          v-for="log in filteredLogs"
          :key="log.id"
          class="px-6 py-3 flex items-center justify-between"
        >
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2">
              <span
                :class="[
                  'w-2 h-2 rounded-full flex-shrink-0',
                  log.status === 'delivered'
                    ? 'bg-green-400'
                    : log.status === 'pending'
                      ? 'bg-yellow-400'
                      : 'bg-red-400',
                ]"
              />
              <span class="text-sm font-mono text-gray-700 truncate">
                {{ log.event }}
              </span>
              <span
                v-if="log.is_test"
                class="text-xs bg-yellow-100 text-yellow-700 px-1.5 py-0.5 rounded font-medium"
              >
                teste
              </span>
            </div>
            <div
              class="flex items-center gap-3 mt-0.5 ml-4 text-xs text-gray-400"
            >
              <span>{{ log.created_at }}</span>
              <span v-if="log.customer_name">{{ log.customer_name }}</span>
              <span v-if="log.attempts > 1">{{ log.attempts }} tentativas</span>
            </div>
          </div>
          <div class="text-right text-xs text-gray-500 flex-shrink-0 ml-4">
            <p
              v-if="log.status_code"
              :class="
                log.status_code >= 200 && log.status_code < 300
                  ? 'text-green-600'
                  : 'text-red-600'
              "
            >
              HTTP {{ log.status_code }}
            </p>
            <p>{{ log.duration_ms }}ms</p>
          </div>
        </div>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { ref, computed, onMounted } from "vue";
import { Link, router, useForm, usePage } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";
import Badge from "@/components/Shared/Badge.vue";
import ConfirmButton from "@/components/Shared/ConfirmButton.vue";

const props = defineProps({
  integration: Object,
  api_keys: { type: Array, default: () => [] },
});

const page = usePage();

const selectedEvent = ref(props.integration.events?.[0] || "");
const testing = ref(false);
const showSecret = ref(false);
const showPortalPreview = ref(false);
const lastResult = ref(null);
const testLogs = ref([]);

// Portal config
const portalConfig = props.integration.portal_config || {
  allow_plan_change: true,
  allow_buy_products: true,
  allow_adjust_extras: true,
  show_invoice_history: true,
  allow_cancel: false,
};

const portalOptions = [
  { key: "allow_plan_change", label: "Trocar de plano" },
  { key: "allow_buy_products", label: "Comprar pacotes" },
  { key: "allow_adjust_extras", label: "Ajustar extras" },
  { key: "show_invoice_history", label: "Histórico de faturas" },
  { key: "allow_cancel", label: "Cancelar assinatura" },
];

// API Keys
const showNewKeyForm = ref(false);
const localApiKeys = ref(props.api_keys);
const appUrl = window.location.origin;

const newToken = ref(page.props.flash?.token || null);

const createForm = useForm({ name: "" });

const createKey = () => {
  createForm.post(
    `/integrations/${props.integration.id}/integration_api_keys`,
    {
      onSuccess: () => {
        showNewKeyForm.value = false;
        createForm.reset();
        newToken.value = page.props.flash?.token || null;
      },
    },
  );
};

const revokeKey = (id) => {
  router.delete(
    `/integrations/${props.integration.id}/integration_api_keys/${id}`,
    {
      preserveState: false,
      onSuccess: () => {
        const key = localApiKeys.value.find((k) => k.id === id);
        if (key) key.active = false;
      },
    },
  );
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
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
            ?.content,
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

// All webhook logs (not just tests)
const allLogs = ref([]);
const logFilter = ref("all");

const filteredLogs = computed(() => {
  if (logFilter.value === "all") return allLogs.value;
  return allLogs.value.filter((l) => l.status === logFilter.value);
});

const loadAllLogs = async () => {
  try {
    const res = await fetch(
      `/integrations/${props.integration.id}/webhook_logs`,
    );
    const data = await res.json();
    allLogs.value = data.logs;
  } catch (e) {
    console.error("Erro ao carregar logs:", e);
  }
};

onMounted(() => {
  loadLogs();
  loadAllLogs();
});
</script>

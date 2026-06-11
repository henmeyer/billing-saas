<template>
  <AppLayout>
    <div class="page-header">
      <div class="flex items-center gap-3">
        <Link
          href="/payment_gateways"
          class="text-sm text-gray-500 hover:text-gray-700"
        >
          ← Gateways
        </Link>
        <h2 class="page-title">
          {{ gateway.id ? "Editar gateway" : "Configurar gateway" }}
        </h2>
      </div>
    </div>

    <div class="max-w-lg space-y-6">
      <div v-if="Object.keys(errors).length" class="alert-danger">
        <p v-for="(msgs, field) in errors" :key="field">
          {{ msgs.join(", ") }}
        </p>
      </div>

      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Configuração</h3>
        </div>
        <div class="card-body space-y-4">
          <div>
            <label class="form-label">Provider</label>
            <select
              v-model="form.provider"
              class="form-input"
              :disabled="!!gateway.id"
            >
              <option value="">Selecione</option>
              <option v-for="p in providers" :key="p" :value="p">
                {{ p }}
              </option>
            </select>
          </div>

          <div>
            <label class="form-label">
              API Key (X-Login)
              <span v-if="gateway.id" class="text-gray-400 font-normal">
                (deixe em branco para manter a atual)
              </span>
            </label>
            <input
              v-model="form.api_key"
              type="password"
              class="form-input font-mono"
              autocomplete="new-password"
              :placeholder="gateway.id ? '••••••••••••••••' : 'sk_live_...'"
            />
            <p class="form-hint">
              Armazenada criptografada. Nunca exibida novamente.
            </p>
          </div>

          <div>
            <label class="form-label">Ambiente</label>
            <select v-model="form.sandbox" class="form-input">
              <option value="true">Sandbox (testes)</option>
              <option value="false">Produção</option>
            </select>
          </div>

          <template v-if="form.provider === 'dlocal_go'">
            <div>
              <label class="form-label">
                Secret Key (X-Secret-Key)
                <span v-if="gateway.id" class="text-gray-400 font-normal">
                  (deixe em branco para manter a atual)
                </span>
              </label>
              <input
                v-model="form.secret_key"
                type="password"
                class="form-input font-mono"
                autocomplete="new-password"
                placeholder="••••••••••••••••"
              />
              <p class="form-hint">
                Diferente da API Key. Encontre em Dashboard → API Credentials.
              </p>
            </div>

            <div>
              <label class="form-label">País padrão</label>
              <select v-model="form.default_country" class="form-input">
                <option value="BR">Brasil (BR)</option>
                <option value="MX">México (MX)</option>
                <option value="CO">Colômbia (CO)</option>
                <option value="AR">Argentina (AR)</option>
                <option value="CL">Chile (CL)</option>
                <option value="PE">Peru (PE)</option>
              </select>
              <p class="form-hint">
                Usado como padrão na criação de pagamentos.
              </p>
            </div>

            <div class="rounded-md bg-blue-50 border border-blue-200 p-3 mt-2">
              <p class="font-medium text-gray-700 text-sm mb-1">
                Configuração dLocal Go:
              </p>
              <ol
                class="text-xs text-gray-600 space-y-1 list-decimal list-inside"
              >
                <li>Acesse dlocalgo.com → Integrações → API</li>
                <li>Copie a API Key e Secret Key</li>
                <li>
                  Configure webhook:
                  <code class="bg-gray-200 px-1 rounded"
                    >{{ webhookUrl }}/webhooks/dlocal_go</code
                  >
                </li>
              </ol>
              <div class="flex gap-2 mt-2">
                <span class="text-blue-500">ℹ</span>
                <span class="text-xs text-blue-700">
                  dLocal Go usa checkout por cobrança: cada pagamento (primeiro
                  e renovações) redireciona o cliente ao checkout, onde ele
                  escolhe Pix, cartão, boleto ou outro método disponível.
                </span>
              </div>
            </div>
          </template>
        </div>
      </div>

      <div class="flex gap-3 justify-end">
        <Link href="/payment_gateways" class="btn-secondary">Cancelar</Link>

        <button
          v-if="gateway.id"
          type="button"
          @click="testConnection"
          :disabled="testing"
          class="btn-secondary"
        >
          {{ testing ? "Testando..." : "🔌 Testar conexão" }}
        </button>

        <button @click="submit" :disabled="form.processing" class="btn-primary">
          {{
            form.processing
              ? "Salvando..."
              : gateway.id
                ? "Salvar"
                : "Configurar"
          }}
        </button>
      </div>

      <!-- Resultado do teste -->
      <div v-if="testResult" class="mt-2">
        <div
          :class="testResult.success ? 'alert-success' : 'alert-danger'"
          class="text-sm"
        >
          {{ testResult.message }}
        </div>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { ref } from "vue";
import { Link, useForm, router } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";

const props = defineProps({
  gateway: Object,
  providers: Array,
  errors: { type: Object, default: () => ({}) },
});

const gateway = props.gateway || {};
const providers = props.providers || [];

const webhookUrl = window.location.origin;

const testing = ref(false);
const testResult = ref(null);

const form = useForm({
  provider: gateway.provider || "",
  api_key: "",
  secret_key: "",
  sandbox: gateway.sandbox != null ? String(gateway.sandbox) : "true",
  default_country: gateway.default_country || "BR",
});

const submit = () => {
  const url = gateway.id
    ? `/payment_gateways/${gateway.id}`
    : "/payment_gateways";
  const method = gateway.id ? "put" : "post";
  form[method](url);
};

const testConnection = async () => {
  testing.value = true;
  testResult.value = null;

  try {
    const response = await fetch(`/payment_gateways/${gateway.id}/test`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
          ?.content,
      },
    });
    testResult.value = await response.json();
  } catch (e) {
    testResult.value = {
      success: false,
      message: "Erro de rede: " + e.message,
    };
  } finally {
    testing.value = false;
  }
};
</script>

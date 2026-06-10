<template>
  <PortalLayout
    :customer="$page.props.customer"
    :branding="branding"
    :portal-config="portalConfig"
  >
    <div class="max-w-lg mx-auto space-y-6">
      <h1 class="text-xl font-semibold text-gray-900">Pagamento</h1>

      <!-- Valor -->
      <div class="card">
        <div class="card-body text-center">
          <p class="text-3xl font-bold text-gray-900">
            {{ fmt(charge.amount_cents) }}
          </p>
          <p v-if="charge.due_date" class="text-sm text-gray-500 mt-1">
            Vencimento: {{ charge.due_date }}
          </p>
        </div>
      </div>

      <!-- Pago! -->
      <div v-if="paid" class="card bg-green-50 border-green-200">
        <div class="card-body text-center py-8">
          <p class="text-4xl mb-3">✓</p>
          <p class="text-lg font-semibold text-green-800">
            Pagamento confirmado!
          </p>
          <p class="text-sm text-green-600 mt-1">
            Os créditos foram adicionados à sua conta.
          </p>
          <Link
            :href="`/portal/${portalToken}`"
            class="btn-primary mt-4 inline-flex"
          >
            Voltar ao painel
          </Link>
        </div>
      </div>

      <template v-else>
        <!-- Pix -->
        <div v-if="charge.pix_qr_code || charge.pix_code" class="card">
          <div class="card-header">
            <h2 class="text-sm font-medium text-gray-900">Pagar com Pix</h2>
          </div>
          <div class="card-body text-center space-y-4">
            <div v-if="charge.pix_qr_code" class="flex justify-center">
              <img
                :src="'data:image/png;base64,' + charge.pix_qr_code"
                class="w-48 h-48 rounded-lg border"
                alt="QR Code Pix"
              />
            </div>

            <div v-if="charge.pix_code">
              <p class="text-xs text-gray-500 mb-1">Pix copia e cola:</p>
              <div class="flex items-center gap-2">
                <code
                  class="flex-1 text-xs bg-gray-100 px-3 py-2 rounded break-all font-mono"
                >
                  {{ charge.pix_code }}
                </code>
                <button
                  @click="copyPix"
                  class="btn-secondary btn-sm flex-shrink-0"
                >
                  {{ copied ? "✓ Copiado" : "Copiar" }}
                </button>
              </div>
            </div>

            <div
              class="flex items-center justify-center gap-2 text-sm text-gray-500"
            >
              <svg class="animate-spin h-4 w-4" viewBox="0 0 24 24" fill="none">
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
              Aguardando confirmação do pagamento...
            </div>
          </div>
        </div>

        <!-- Boleto -->
        <div v-if="charge.boleto_url" class="card">
          <div class="card-header">
            <h2 class="text-sm font-medium text-gray-900">Pagar com Boleto</h2>
          </div>
          <div class="card-body space-y-3">
            <div v-if="charge.boleto_barcode">
              <p class="text-xs text-gray-500 mb-1">Código de barras:</p>
              <code
                class="text-xs bg-gray-100 px-3 py-2 rounded block font-mono break-all"
              >
                {{ charge.boleto_barcode }}
              </code>
            </div>
            <a
              :href="charge.boleto_url"
              target="_blank"
              class="btn-primary w-full justify-center inline-flex"
            >
              Abrir boleto
            </a>
          </div>
        </div>
      </template>
    </div>
  </PortalLayout>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from "vue";
import { Link, usePage } from "@inertiajs/vue3";
import PortalLayout from "@/components/Portal/PortalLayout.vue";

const props = defineProps({
  charge: Object,
  portal_config: Object,
  branding: Object,
});

const page = usePage();
const portalToken = page.props.portal_token;
const portalConfig = props.portal_config;
const paid = ref(props.charge.status === "paid");
const copied = ref(false);
let polling = null;

const copyPix = async () => {
  await navigator.clipboard.writeText(props.charge.pix_code);
  copied.value = true;
  setTimeout(() => {
    copied.value = false;
  }, 3000);
};

const checkStatus = async () => {
  try {
    const res = await fetch(
      `/portal/${portalToken}/checkout/${props.charge.id}/status`,
    );
    const data = await res.json();
    if (data.paid) {
      paid.value = true;
      stopPolling();
    }
  } catch (e) {
    console.error("Erro no polling:", e);
  }
};

const startPolling = () => {
  polling = setInterval(checkStatus, 3000);
};

const stopPolling = () => {
  if (polling) {
    clearInterval(polling);
    polling = null;
  }
};

onMounted(() => {
  if (!paid.value) startPolling();
});

onUnmounted(stopPolling);

const fmt = (v) =>
  new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(
    (v || 0) / 100,
  );
</script>

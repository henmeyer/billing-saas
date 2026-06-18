<template>
  <PortalLayout :customer="customer" :branding="branding" :portal-config="portalConfig">
    <div class="max-w-md mx-auto space-y-6">
      <div class="text-center">
        <h1 class="text-xl font-semibold text-gray-900">Ativar assinatura</h1>
        <p class="text-sm text-gray-500 mt-1">Plano {{ subscription.plan_name }}</p>
      </div>

      <!-- Valor -->
      <div class="card">
        <div class="card-body text-center py-6">
          <p class="text-3xl font-bold text-gray-900">
            {{ fmt(subscription.base_price_cents) }}
          </p>
          <p class="text-sm text-gray-500">/mês</p>
        </div>
      </div>

      <!-- Gateway resolvido automaticamente -->
      <div class="card">
        <div class="card-header">
          <h2 class="text-sm font-medium text-gray-900">Método de pagamento</h2>
          <p class="text-xs text-gray-500 mt-0.5">
            Selecionamos as melhores opções para o seu país.
          </p>
        </div>
        <div class="card-body space-y-2">
          <label
            v-for="method in paymentMethods"
            :key="method.id"
            class="flex items-center gap-3 p-3 rounded-lg border-2 cursor-pointer transition-all"
            :class="
              selectedMethod === method.id
                ? 'border-[var(--portal-primary)] bg-[var(--portal-primary)]/5'
                : 'border-gray-200 hover:border-gray-300'
            "
          >
            <input
              v-model="selectedMethod"
              :value="method.id"
              type="radio"
              name="payment_method"
              class="text-[var(--portal-primary)] focus:ring-[var(--portal-primary)]"
            />

            <div class="w-8 h-8 rounded bg-gray-100 flex items-center justify-center flex-shrink-0">
              <span v-if="method.icon === 'pix'" class="text-sm font-bold text-teal-600">PIX</span>
              <span v-else-if="method.icon === 'boleto'" class="text-xs font-bold text-gray-600">BOL</span>
              <span v-else-if="method.icon === 'card'" class="text-sm">💳</span>
              <span v-else class="text-sm">🏦</span>
            </div>

            <div>
              <p class="text-sm font-medium text-gray-900">{{ method.label }}</p>
              <p v-if="method.id === 'PIX'" class="text-xs text-gray-400">
                Aprovação instantânea
              </p>
              <p v-else-if="method.id === 'BOLETO'" class="text-xs text-gray-400">
                Aprovação em até 3 dias úteis
              </p>
              <p
                v-else-if="method.id === 'CARD' || method.id === 'CREDIT_CARD'"
                class="text-xs text-gray-400"
              >
                Aprovação imediata
              </p>
            </div>
          </label>
        </div>
      </div>

      <!-- Info de segurança -->
      <div class="flex items-center gap-2 text-xs text-gray-400 justify-center">
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
          />
        </svg>
        <span>Pagamento processado com segurança via {{ providerLabel }}</span>
      </div>

      <!-- Botão -->
      <button
        @click="pay"
        :disabled="!selectedMethod || processing"
        class="w-full py-3 rounded-lg font-semibold text-white transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        :style="{ backgroundColor: branding.primary_color || '#6366f1' }"
      >
        {{ processing ? "Processando..." : `Pagar ${fmt(subscription.base_price_cents)}` }}
      </button>
    </div>
  </PortalLayout>
</template>

<script setup>
import { ref, computed } from "vue";
import { router, usePage } from "@inertiajs/vue3";
import PortalLayout from "@/components/Portal/PortalLayout.vue";

const props = defineProps({
  customer: Object,
  subscription: Object,
  provider: String,
  payment_methods: Array,
  portal_config: Object,
  branding: Object,
});

const page = usePage();
const portalConfig = props.portal_config;
const paymentMethods = props.payment_methods || [];
const selectedMethod = ref(paymentMethods[0]?.id || "");
const processing = ref(false);

const providerLabel = computed(
  () =>
    ({
      asaas: "Asaas",
      stripe: "Stripe",
      dlocal_go: "dLocal Go",
    })[props.provider] || props.provider,
);

const pay = () => {
  processing.value = true;
  router.post(`/portal/${page.props.portal_token}/conversion`, {
    payment_method: selectedMethod.value,
  });
};

const fmt = (v) =>
  new Intl.NumberFormat("pt-BR", {
    style: "currency",
    currency: props.subscription?.currency_code || "BRL",
  }).format((v || 0) / 100);
</script>

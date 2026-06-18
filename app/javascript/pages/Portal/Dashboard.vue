<template>
  <PortalLayout
    :customer="customer"
    :branding="branding"
    :portal-config="portalConfig"
  >
    <h1 class="text-xl font-semibold text-gray-900 mb-6">Minha assinatura</h1>

    <div v-if="!subscription" class="card">
      <div class="card-body text-center py-12 text-gray-400">
        <p>Você não possui uma assinatura ativa.</p>
        <Link
          v-if="portalConfig.allow_plan_change"
          :href="p('/plans')"
          class="btn-primary mt-4 inline-flex"
        >
          Ver planos disponíveis
        </Link>
      </div>
    </div>

    <template v-else>
      <!-- Banner de trial -->
      <div v-if="subscription.is_trial" class="card overflow-hidden mb-6">
        <div
          :class="[
            'px-6 py-4',
            subscription.trial_expired
              ? 'bg-red-50 border-b border-red-200'
              : subscription.trial_days_remaining <= 3
                ? 'bg-amber-50 border-b border-amber-200'
                : 'bg-blue-50 border-b border-blue-200',
          ]"
        >
          <div class="flex items-center justify-between">
            <div>
              <p
                :class="[
                  'text-sm font-semibold',
                  subscription.trial_expired
                    ? 'text-red-800'
                    : subscription.trial_days_remaining <= 3
                      ? 'text-amber-800'
                      : 'text-blue-800',
                ]"
              >
                {{
                  subscription.trial_expired
                    ? "Seu período de teste expirou"
                    : `Teste grátis — ${subscription.trial_days_remaining} dia(s) restante(s)`
                }}
              </p>
              <p
                :class="[
                  'text-xs mt-0.5',
                  subscription.trial_expired
                    ? 'text-red-600'
                    : subscription.trial_days_remaining <= 3
                      ? 'text-amber-600'
                      : 'text-blue-600',
                ]"
              >
                {{
                  subscription.trial_expired
                    ? "Comece a pagar para continuar usando o serviço."
                    : `Expira em ${subscription.trial_ends_at}. Após isso, será necessário realizar o pagamento.`
                }}
              </p>
            </div>
            <Link
              :href="p('/conversion/new')"
              :class="[
                'px-4 py-2 rounded-lg text-sm font-semibold transition-colors',
                subscription.trial_expired
                  ? 'bg-red-600 text-white hover:bg-red-700'
                  : 'bg-[var(--portal-primary)] text-white hover:opacity-90',
              ]"
            >
              {{ subscription.trial_expired ? "Ativar agora" : "Começar a pagar" }}
            </Link>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Plano atual -->
        <div class="lg:col-span-2 space-y-4">
          <div class="card">
            <div class="card-body">
              <div class="flex items-center justify-between mb-4">
                <div>
                  <h2 class="text-lg font-semibold text-gray-900">
                    {{ subscription.plan_name }}
                  </h2>
                  <p
                    v-if="subscription.plan_description"
                    class="text-sm text-gray-500 mt-0.5"
                  >
                    {{ subscription.plan_description }}
                  </p>
                </div>
                <Badge :variant="statusVariant">{{ statusLabel }}</Badge>
              </div>

              <!-- Preço -->
              <div v-if="subscription.is_trial" class="bg-gray-50 rounded-lg px-4 py-3">
                <div class="flex justify-between text-sm">
                  <span class="text-gray-500">Valor após o teste</span>
                  <span class="text-gray-400 line-through">
                    {{ fmt(subscription.base_price_cents) }}/mês
                  </span>
                </div>
                <div class="flex justify-between font-semibold text-base mt-1">
                  <span>Agora</span>
                  <span class="text-green-600">Grátis</span>
                </div>
              </div>

              <div v-else class="bg-gray-50 rounded-lg px-4 py-3 space-y-1.5">
                <div class="flex justify-between text-sm">
                  <span class="text-gray-500">Valor base</span>
                  <span>{{ fmt(subscription.base_price_cents) }}/mês</span>
                </div>
                <div
                  v-if="subscription.has_extras"
                  class="flex justify-between text-sm"
                >
                  <span class="text-gray-500">Extras</span>
                  <span>+ {{ fmt(subscription.period_extras_cents) }}</span>
                </div>
                <div
                  class="flex justify-between font-semibold text-base border-t border-gray-200 pt-1.5"
                >
                  <span>Total</span>
                  <span>{{ fmt(subscription.period_amount_cents) }}</span>
                </div>
              </div>

              <p v-if="!subscription.is_trial" class="text-xs text-gray-400 mt-3">
                Próxima renovação: {{ subscription.current_period_end }}
              </p>

              <!-- Ações -->
              <div class="flex gap-2 mt-4 pt-3 border-t border-gray-100">
                <Link
                  v-if="portalConfig.allow_plan_change"
                  :href="p('/plans')"
                  class="btn-secondary btn-sm"
                >
                  Trocar de plano
                </Link>
                <button
                  v-if="portalConfig.allow_cancel"
                  @click="showCancelConfirm = true"
                  class="btn-sm text-red-600 border border-red-200 hover:bg-red-50 rounded-lg px-3 py-1.5 text-sm"
                >
                  Cancelar assinatura
                </button>
              </div>
            </div>
          </div>

          <!-- Créditos -->
          <div v-if="credits.length" class="card">
            <div class="card-header">
              <h3 class="text-sm font-medium text-gray-900">Uso de créditos</h3>
            </div>
            <div class="card-body space-y-4">
              <div v-for="c in credits" :key="c.key">
                <div class="flex justify-between text-sm mb-1">
                  <span class="font-medium text-gray-700">{{ c.label }}</span>
                  <span class="text-gray-500">
                    {{ fmtNum(c.used) }} / {{ fmtNum(c.limit) }} {{ c.unit }}s
                  </span>
                </div>
                <div
                  class="w-full h-2 bg-gray-200 rounded-full overflow-hidden"
                >
                  <div
                    :class="[
                      'h-full rounded-full transition-all',
                      c.usage_percent >= 100
                        ? 'bg-red-500'
                        : c.usage_percent >= 80
                          ? 'bg-amber-500'
                          : 'bg-[var(--portal-primary)]',
                    ]"
                    :style="{ width: Math.min(c.usage_percent, 100) + '%' }"
                  />
                </div>
                <p v-if="c.extras > 0" class="text-xs text-gray-400 mt-1">
                  Base: {{ fmtNum(c.base) }} + Extras: {{ fmtNum(c.extras) }}
                </p>
              </div>
            </div>
          </div>

          <!-- Licenças -->
          <div v-if="licenses.length" class="card">
            <div class="card-header">
              <h3 class="text-sm font-medium text-gray-900">Licenças</h3>
            </div>
            <div class="card-body">
              <div
                v-for="l in licenses"
                :key="l.key"
                class="flex justify-between text-sm py-2 border-b border-gray-50 last:border-0"
              >
                <span class="text-gray-600">{{ l.label }}</span>
                <span class="font-medium text-gray-900">
                  {{ l.unlimited ? "∞" : l.used + " / " + l.quantity }}
                  {{ l.unit }}(s)
                </span>
              </div>
            </div>
          </div>
        </div>

        <!-- Sidebar direita -->
        <div class="space-y-4">
          <!-- Features -->
          <div v-if="features.length" class="card">
            <div class="card-header">
              <h3 class="text-sm font-medium text-gray-900">
                Recursos do plano
              </h3>
            </div>
            <div class="card-body">
              <div
                v-for="f in features"
                :key="f.key"
                class="flex items-center gap-2 py-1.5 text-sm"
              >
                <span :class="f.enabled ? 'text-green-500' : 'text-gray-300'">
                  {{ f.enabled ? "✓" : "✕" }}
                </span>
                <span :class="f.enabled ? 'text-gray-700' : 'text-gray-400'">
                  {{ f.label }}
                </span>
              </div>
            </div>
          </div>

          <!-- Comprar extras -->
          <div v-if="portalConfig.allow_buy_products" class="card">
            <div class="card-body text-center py-6">
              <p class="text-sm text-gray-600 mb-3">
                Precisa de mais créditos?
              </p>
              <Link
                :href="p('/products')"
                class="btn-primary inline-flex text-sm"
              >
                Comprar pacotes
              </Link>
            </div>
          </div>
        </div>
      </div>

      <!-- Modal de cancelamento -->
      <div
        v-if="showCancelConfirm"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm"
      >
        <div class="bg-white rounded-xl shadow-xl max-w-sm w-full mx-4 p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-2">
            Cancelar assinatura?
          </h3>
          <p class="text-sm text-gray-600 mb-6">
            Sua assinatura será cancelada imediatamente. Você perderá o acesso
            aos recursos do plano atual.
          </p>
          <div class="flex gap-3 justify-end">
            <button @click="showCancelConfirm = false" class="btn-secondary">
              Voltar
            </button>
            <Link
              :href="p('/subscription')"
              method="delete"
              as="button"
              class="btn-sm bg-red-600 text-white hover:bg-red-700 rounded-lg px-4 py-2 text-sm font-medium"
            >
              Confirmar cancelamento
            </Link>
          </div>
        </div>
      </div>
    </template>
  </PortalLayout>
</template>

<script setup>
import { ref, computed } from "vue";
import { Link, usePage } from "@inertiajs/vue3";
import PortalLayout from "@/components/Portal/PortalLayout.vue";
import Badge from "@/components/Shared/Badge.vue";

const props = defineProps({
  customer: Object,
  subscription: Object,
  credits: Array,
  licenses: Array,
  features: Array,
  portal_config: Object,
  branding: Object,
});

const page = usePage();
const portalConfig = props.portal_config;
const showCancelConfirm = ref(false);

const p = (path) => `/portal/${page.props.portal_token}${path}`;

const statusVariant = computed(
  () =>
    ({
      active: "green",
      past_due: "red",
      trialing: "blue",
      cancelled: "gray",
    })[props.subscription?.status] || "gray",
);

const statusLabel = computed(
  () =>
    ({
      active: "Ativo",
      past_due: "Inadimplente",
      trialing: "Avaliação",
      cancelled: "Cancelado",
    })[props.subscription?.status] || props.subscription?.status,
);

const fmt = (v) =>
  new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(
    (v || 0) / 100,
  );
const fmtNum = (v) => new Intl.NumberFormat("pt-BR").format(v || 0);
</script>

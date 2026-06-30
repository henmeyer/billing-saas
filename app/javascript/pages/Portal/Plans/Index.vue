<template>
  <PortalLayout
    :customer="$page.props.customer"
    :branding="branding"
    :portal-config="portalConfig"
  >
    <h1 class="text-xl font-semibold text-gray-900 mb-6">Escolha seu plano</h1>

    <div
      v-if="scheduled"
      class="mb-6 rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800"
    >
      Mudança para <strong>{{ scheduled.plan_name }}</strong> agendada para
      {{ fmtDate(scheduled.effective_at) }}. O plano atual permanece até lá.
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <div
        v-for="plan in plans"
        :key="plan.id"
        :class="[
          'card relative overflow-hidden transition-shadow',
          plan.is_current ? 'ring-2 ring-[var(--portal-primary)]' : '',
        ]"
      >
        <!-- Badge plano atual -->
        <div
          v-if="plan.is_current"
          class="absolute top-0 right-0 bg-[var(--portal-primary)] text-white text-xs font-medium px-3 py-1 rounded-bl-lg"
        >
          Plano atual
        </div>

        <div class="card-body space-y-4">
          <div>
            <h3 class="text-lg font-semibold text-gray-900">{{ plan.name }}</h3>
            <p v-if="plan.description" class="text-sm text-gray-500 mt-0.5">
              {{ plan.description }}
            </p>
          </div>

          <div>
            <span class="text-2xl font-bold text-gray-900">
              {{ fmt(plan.price_cents) }}
            </span>
            <span class="text-sm text-gray-500">/mês</span>
          </div>

          <!-- Features incluídas -->
          <div class="space-y-1.5">
            <div
              v-for="f in plan.features"
              :key="f.label"
              class="flex items-center gap-2 text-sm"
            >
              <span class="text-green-500">✓</span>
              <span class="text-gray-600">{{ f.label }}</span>
            </div>
          </div>

          <!-- Créditos -->
          <div v-if="plan.credits.length" class="border-t border-gray-100 pt-3">
            <div
              v-for="c in plan.credits"
              :key="c.label"
              class="flex justify-between text-sm text-gray-600 py-0.5"
            >
              <span>{{ c.label }}</span>
              <span class="font-medium">
                {{ fmtNum(c.quantity) }} {{ c.unit }}s/mês
              </span>
            </div>
          </div>

          <!-- Licenças -->
          <div
            v-if="plan.licenses.length"
            class="border-t border-gray-100 pt-3"
          >
            <div
              v-for="l in plan.licenses"
              :key="l.label"
              class="flex justify-between text-sm text-gray-600 py-0.5"
            >
              <span>{{ l.label }}</span>
              <span class="font-medium">
                {{ l.quantity === 0 ? "Ilimitado" : fmtNum(l.quantity) }}
              </span>
            </div>
          </div>

          <!-- Botão -->
          <div class="pt-2">
            <button
              v-if="plan.is_current"
              disabled
              class="w-full btn-secondary opacity-50 cursor-not-allowed justify-center"
            >
              Plano atual
            </button>
            <template v-else>
              <p
                v-if="
                  plan.price_cents > currentPriceCents && proratedFor(plan) > 0
                "
                class="text-xs text-gray-500 mb-2 text-center"
              >
                Diferença proporcional hoje:
                <strong>{{ fmt(proratedFor(plan)) }}</strong>
                ({{ prorateInfo.days_remaining }} dias restantes)
              </p>
              <p
                v-else-if="plan.price_cents <= currentPriceCents"
                class="text-xs text-gray-500 mb-2 text-center"
              >
                Agendado para o fim do período atual.
              </p>
              <ConfirmButton
                :message="confirmMessage(plan)"
                btn-class="w-full btn-primary justify-center"
                @confirm="changePlan(plan.id)"
              >
                {{
                  plan.price_cents > currentPriceCents
                    ? "Fazer upgrade"
                    : "Trocar plano"
                }}
              </ConfirmButton>
            </template>
          </div>
        </div>
      </div>
    </div>
  </PortalLayout>
</template>

<script setup>
import { router, usePage } from "@inertiajs/vue3";
import PortalLayout from "@/components/Portal/PortalLayout.vue";
import ConfirmButton from "@/components/Shared/ConfirmButton.vue";

const props = defineProps({
  plans: Array,
  current_plan_id: Number,
  currency_code: String,
  prorate_info: { type: Object, default: () => ({}) },
  scheduled: { type: Object, default: null },
  portal_config: Object,
  branding: Object,
});

const page = usePage();
const portalConfig = props.portal_config;
const scheduled = props.scheduled;
const prorateInfo = props.prorate_info || {};
const currentPriceCents =
  props.plans.find((p) => p.is_current)?.price_cents || 0;

// Estima a diferença pró-rata de um upgrade pelos dias restantes do ciclo.
const proratedFor = (plan) => {
  const diff = (plan.price_cents || 0) - currentPriceCents;
  if (diff <= 0) return 0;
  const total = prorateInfo.days_total || 0;
  const remaining = prorateInfo.days_remaining || 0;
  if (total <= 0) return diff;
  return Math.round((diff * remaining) / total);
};

const confirmMessage = (plan) => {
  if (plan.price_cents > currentPriceCents) {
    const prorated = proratedFor(plan);
    return prorated > 0
      ? `Fazer upgrade para ${plan.name}? Você será redirecionado para pagar ${fmt(prorated)} (diferença proporcional).`
      : `Fazer upgrade para ${plan.name}? Será aplicado no próximo ciclo.`;
  }
  return `Trocar para ${plan.name}? A mudança será agendada para o fim do período atual.`;
};

const changePlan = (planId) =>
  router.put(`/portal/${page.props.portal_token}/plans/${planId}`);

const fmt = (v) =>
  new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(
    (v || 0) / 100,
  );
const fmtNum = (v) => new Intl.NumberFormat("pt-BR").format(v || 0);
const fmtDate = (iso) => (iso ? new Date(iso).toLocaleDateString("pt-BR") : "");
</script>

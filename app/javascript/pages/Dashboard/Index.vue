<template>
  <AppLayout>
    <div class="page-header">
      <h2 class="page-title">Dashboard</h2>
    </div>

    <!-- Stats -->
    <div class="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4 mb-6">
      <StatCard label="MRR" :value="fmt(stats.mrr)" />
      <StatCard label="ARR" :value="fmt(stats.arr)" />
      <StatCard label="Clientes ativos" :value="stats.active_customers" />
      <StatCard label="Receita no mês" :value="fmt(stats.revenue_this_month)" />
      <StatCard label="Cancelamentos" :value="stats.churned_this_month" sub="este mês" />
      <StatCard
        label="Inadimplentes"
        :value="stats.past_due"
        :value-class="stats.past_due > 0 ? 'text-red-600' : ''"
      />
    </div>

    <!-- Alertas -->
    <div v-if="hasAlerts" class="space-y-2 mb-6">
      <div v-if="stats.past_due > 0" class="alert-warning">
        <span>⚠</span>
        <span><strong>{{ stats.past_due }} assinatura(s)</strong> com pagamento em atraso.</span>
      </div>
      <div v-if="stats.at_risk > 0" class="alert-warning">
        <span>⚠</span>
        <span><strong>{{ stats.at_risk }} cliente(s)</strong> com health score baixo.</span>
      </div>
      <div v-if="stats.credits_depleted > 0" class="alert-danger">
        <span>✕</span>
        <span><strong>{{ stats.credits_depleted }} cliente(s)</strong> com créditos esgotados.</span>
      </div>
    </div>

    <!-- Gráfico + cobranças -->
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
      <!-- MRR por plano -->
      <div class="lg:col-span-2 card">
        <div class="card-header">
          <h2 class="text-sm font-medium text-gray-900">MRR por plano</h2>
        </div>
        <div class="card-body">
          <div v-if="hasMrrData" class="space-y-3">
            <div v-for="(value, plan) in stats.mrr_by_plan" :key="plan">
              <div class="flex justify-between text-sm mb-1">
                <span class="text-gray-700 font-medium">{{ plan }}</span>
                <span class="text-gray-900">{{ fmt(value) }}</span>
              </div>
              <div class="w-full bg-gray-100 rounded-full h-2">
                <div
                  class="bg-brand-500 h-2 rounded-full transition-all"
                  :style="{ width: mrrPercent(value) + '%' }"
                />
              </div>
            </div>
            <div class="pt-3 border-t border-gray-100 flex justify-between text-sm">
              <span class="text-gray-500">Total MRR</span>
              <span class="font-semibold text-gray-900">{{ fmt(stats.mrr) }}</span>
            </div>
          </div>
          <div v-else class="text-center py-8 text-sm text-gray-400">
            Nenhum plano ativo ainda
          </div>
        </div>
      </div>

      <!-- Últimas cobranças -->
      <div class="card">
        <div class="card-header flex items-center justify-between">
          <h2 class="text-sm font-medium text-gray-900">Últimas cobranças</h2>
          <Link href="/customers" class="text-xs text-brand-600 hover:text-brand-700">
            Ver todas
          </Link>
        </div>
        <div class="divide-y divide-gray-100">
          <div
            v-if="!stats.recent_charges?.length"
            class="px-6 py-8 text-center text-sm text-gray-400"
          >
            Nenhuma cobrança ainda
          </div>
          <div
            v-for="charge in stats.recent_charges"
            :key="charge.created_at"
            class="px-6 py-3 flex items-center justify-between"
          >
            <div>
              <p class="text-sm font-medium text-gray-900 truncate max-w-[120px]">
                {{ charge.customer_name }}
              </p>
              <p class="text-xs text-gray-400">{{ charge.created_at }}</p>
            </div>
            <div class="text-right">
              <p class="text-sm font-medium text-gray-900">{{ fmt(charge.amount) }}</p>
              <Badge :variant="charge.status === 'paid' ? 'green' : 'yellow'">
                {{ charge.status === "paid" ? "Pago" : charge.status }}
              </Badge>
            </div>
          </div>
        </div>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { computed } from "vue";
import { Link } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";
import StatCard from "@/components/Shared/StatCard.vue";
import Badge from "@/components/Shared/Badge.vue";

const props = defineProps({
  stats: Object,
});

const hasAlerts = computed(
  () =>
    props.stats.past_due > 0 ||
    props.stats.at_risk > 0 ||
    props.stats.credits_depleted > 0,
);
const hasMrrData = computed(
  () => Object.keys(props.stats.mrr_by_plan || {}).length > 0,
);

const mrrTotal = computed(() =>
  Object.values(props.stats.mrr_by_plan || {}).reduce((a, b) => a + b, 0),
);
const mrrPercent = (value) =>
  mrrTotal.value > 0 ? Math.round((value / mrrTotal.value) * 100) : 0;

const fmt = (val) =>
  new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(val || 0);
</script>

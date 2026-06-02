<template>
  <div class="stats-grid">
    <div class="stat-card" v-for="stat in mainStats" :key="stat.label">
      <div class="stat-label">{{ stat.label }}</div>
      <div class="stat-value">{{ stat.value }}</div>
      <div class="stat-sub" v-if="stat.sub">{{ stat.sub }}</div>
    </div>
  </div>

  <div class="alerts" v-if="stats.past_due > 0 || stats.at_risk > 0">
    <div class="alert alert-warning" v-if="stats.past_due > 0">
      {{ stats.past_due }} assinatura(s) com pagamento em atraso
    </div>
    <div class="alert alert-danger" v-if="stats.at_risk > 0">
      {{ stats.at_risk }} cliente(s) em risco de churn
    </div>
  </div>

  <div class="recent-charges">
    <h3>Últimas cobranças</h3>
    <table>
      <thead>
        <tr>
          <th>Cliente</th>
          <th>Valor</th>
          <th>Status</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="charge in stats.recent_charges" :key="charge.created_at">
          <td>{{ charge.customer_name }}</td>
          <td>{{ formatCurrency(charge.amount) }}</td>
          <td>
            <span :class="['badge', `badge-${charge.status}`]">
              {{ charge.status }}
            </span>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script setup>
import { computed } from "vue";

const props = defineProps({
  stats: { type: Object, required: true },
});

const mainStats = computed(() => [
  { label: "MRR", value: formatCurrency(props.stats.mrr) },
  { label: "ARR", value: formatCurrency(props.stats.arr) },
  { label: "Clientes ativos", value: props.stats.active_customers },
  {
    label: "Receita no mês",
    value: formatCurrency(props.stats.revenue_this_month),
  },
  {
    label: "Cancelamentos",
    value: props.stats.churned_this_month,
    sub: "este mês",
  },
  {
    label: "Créditos esgotados",
    value: props.stats.credits_depleted,
    sub: "este mês",
  },
]);

const formatCurrency = (val) =>
  new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(
    val,
  );
</script>

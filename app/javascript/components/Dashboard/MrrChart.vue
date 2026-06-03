<template>
  <div v-if="hasData">
    <div class="space-y-3">
      <div v-for="(value, plan) in mrrByPlan" :key="plan">
        <div class="flex justify-between text-sm mb-1">
          <span class="text-gray-700 font-medium">{{ plan }}</span>
          <span class="text-gray-900">{{ formatCurrency(value) }}</span>
        </div>
        <div class="w-full bg-gray-100 rounded-full h-2">
          <div
            class="bg-brand-500 h-2 rounded-full transition-all"
            :style="{ width: percentage(value) + '%' }"
          ></div>
        </div>
      </div>
    </div>
    <div class="mt-4 pt-4 border-t border-gray-100 flex justify-between text-sm">
      <span class="text-gray-500">Total MRR</span>
      <span class="font-semibold text-gray-900">{{ formatCurrency(total) }}</span>
    </div>
  </div>
  <div v-else class="text-center py-8 text-sm text-gray-400">
    Nenhum plano ativo ainda
  </div>
</template>

<script setup>
import { computed } from "vue";

const props = defineProps({
  mrrByPlan: { type: Object, default: () => ({}) },
});

const total = computed(() =>
  Object.values(props.mrrByPlan).reduce((a, b) => a + b, 0),
);

const hasData = computed(() => total.value > 0);

const percentage = (value) =>
  total.value > 0 ? Math.round((value / total.value) * 100) : 0;

const formatCurrency = (val) =>
  new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(val);
</script>

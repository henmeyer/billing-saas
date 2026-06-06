<template>
  <div>
    <div class="flex justify-between text-sm mb-1">
      <span class="font-medium text-gray-700">{{ label }}</span>
      <span class="text-gray-500">{{ used }} / {{ limit }} {{ unit }}</span>
    </div>
    <div class="w-full bg-gray-100 rounded-full h-2">
      <div
        :class="['h-2 rounded-full transition-all', barClass]"
        :style="{ width: Math.min(percent, 100) + '%' }"
      />
    </div>
    <div class="flex justify-between text-xs text-gray-400 mt-0.5">
      <span>{{ percent }}% utilizado</span>
      <span>{{ balance }} restantes</span>
    </div>
  </div>
</template>

<script setup>
import { computed } from "vue";

const props = defineProps({
  label: String,
  used: Number,
  limit: Number,
  balance: Number,
  percent: Number,
  unit: String,
});

const barClass = computed(() =>
  props.percent >= 100
    ? "bg-red-500"
    : props.percent >= 80
      ? "bg-yellow-500"
      : "bg-brand-500",
);
</script>

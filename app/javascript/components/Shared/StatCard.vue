<template>
  <div class="stat-card">
    <div class="stat-label">{{ label }}</div>
    <div :class="['stat-value', valueClass]">{{ value }}</div>
    <div v-if="sub" class="stat-sub">{{ sub }}</div>
  </div>
</template>

<script setup>
defineProps({
  label: String,
  value: [String, Number],
  sub: String,
  valueClass: { type: String, default: "" },
});
</script>

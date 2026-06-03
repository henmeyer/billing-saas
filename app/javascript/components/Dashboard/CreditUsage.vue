<template>
  <div class="space-y-3">
    <div v-for="snapshot in snapshots" :key="snapshot.id">
      <div class="flex justify-between text-sm mb-1">
        <span class="font-medium text-gray-700">{{ snapshot.label }}</span>
        <span class="text-gray-500">{{ snapshot.used }} / {{ snapshot.limit }} {{ snapshot.unit }}s</span>
      </div>
      <div class="w-full bg-gray-100 rounded-full h-2">
        <div
          :class="barClass(snapshot.usage_percent)"
          class="h-2 rounded-full transition-all"
          :style="{ width: Math.min(snapshot.usage_percent, 100) + '%' }"
        ></div>
      </div>
    </div>
  </div>
</template>

<script setup>
defineProps({
  snapshots: { type: Array, default: () => [] },
});

const barClass = (pct) => {
  if (pct >= 100) return "bg-red-500";
  if (pct >= 80) return "bg-yellow-500";
  return "bg-brand-500";
};
</script>

<template>
  <div :class="['flex items-center gap-2 px-3 pt-4 pb-1']">
    <!-- Linha de separação para superadmin -->
    <div v-if="variant === 'warning'" class="h-px flex-1 bg-amber-500/30" />

    <p
      :class="[
        'text-xs font-semibold uppercase tracking-wider whitespace-nowrap',
        variant === 'warning' ? 'text-amber-500/70' : 'text-gray-500',
      ]"
    >
      {{ label }}
    </p>

    <div v-if="variant === 'warning'" class="h-px flex-1 bg-amber-500/30" />
  </div>
</template>

<script setup>
defineProps({
  label: String,
  variant: { type: String, default: "default" },
});
</script>

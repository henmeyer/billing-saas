<template>
  <span :class="['badge', variantClass]">
    <slot />
  </span>
</template>

<script setup>
import { computed } from "vue";

const props = defineProps({
  variant: { type: String, default: "gray" },
});

const variantClass = computed(
  () =>
    ({
      green: "badge-green",
      red: "badge-red",
      yellow: "badge-yellow",
      gray: "badge-gray",
      blue: "badge-blue",
    })[props.variant] || "badge-gray",
);
</script>

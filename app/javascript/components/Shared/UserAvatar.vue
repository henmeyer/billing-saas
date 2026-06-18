<template>
  <div :class="[sizeClass, 'rounded-full flex-shrink-0 overflow-hidden']">
    <img
      v-if="avatarUrl"
      :src="avatarUrl"
      class="w-full h-full object-cover"
      :alt="name"
    />
    <div
      v-else
      :class="[
        sizeClass,
        'bg-brand-600 flex items-center justify-center text-white font-semibold rounded-full',
      ]"
      :style="{ fontSize: fontSize }"
    >
      {{ computedInitials }}
    </div>
  </div>
</template>

<script setup>
import { computed } from "vue";

const props = defineProps({
  avatarUrl: { type: String, default: null },
  name: { type: String, default: "" },
  initials: { type: String, default: null },
  size: { type: String, default: "md" },
});

const computedInitials = computed(
  () =>
    props.initials ||
    props.name
      .split(" ")
      .map((w) => w[0])
      .slice(0, 2)
      .join("")
      .toUpperCase(),
);

const sizeClass = computed(
  () =>
    ({
      sm: "w-6 h-6",
      md: "w-8 h-8",
      lg: "w-10 h-10",
      xl: "w-16 h-16",
      "2xl": "w-20 h-20",
    })[props.size] || "w-8 h-8",
);

const fontSize = computed(
  () =>
    ({
      sm: "0.6rem",
      md: "0.7rem",
      lg: "0.8rem",
      xl: "1.1rem",
      "2xl": "1.4rem",
    })[props.size] || "0.7rem",
);
</script>

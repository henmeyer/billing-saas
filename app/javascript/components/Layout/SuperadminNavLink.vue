<template>
  <Link
    :href="href"
    :class="[
      'flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm font-medium transition-colors',
      isActive
        ? 'bg-gray-800 text-white'
        : 'text-gray-500 hover:bg-gray-800 hover:text-white',
    ]"
  >
    <span class="text-base leading-none">{{ icon }}</span>
    <span>{{ label }}</span>
  </Link>
</template>

<script setup>
import { Link, usePage } from "@inertiajs/vue3";
import { computed } from "vue";

const props = defineProps({
  href: String,
  icon: String,
  label: String,
  exact: { type: Boolean, default: false },
});

const page = usePage();
const isActive = computed(() =>
  props.exact
    ? page.url === props.href
    : page.url === props.href || page.url.startsWith(props.href + "/"),
);
</script>

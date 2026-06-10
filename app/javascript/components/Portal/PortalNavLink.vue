<template>
  <Link
    :href="href"
    :class="[
      'px-3 py-1.5 text-sm rounded-lg transition-colors',
      isActive
        ? 'bg-gray-100 text-gray-900 font-medium'
        : 'text-gray-500 hover:text-gray-700 hover:bg-gray-50',
    ]"
  >
    {{ label }}
  </Link>
</template>

<script setup>
import { computed } from "vue";
import { Link, usePage } from "@inertiajs/vue3";

const props = defineProps({ href: String, label: String });
const page = usePage();

// Compara o path relativo sem o prefixo /portal/:token
const isActive = computed(() => {
  const url = page.url;
  const token = page.props.portal_token;
  const base = `/portal/${token}`;

  // Extrai o "subpath" da URL atual (ex: /plans, /products, "")
  const currentSub = url.startsWith(base) ? url.slice(base.length) || "/" : url;
  const linkSub = props.href.startsWith(base)
    ? props.href.slice(base.length) || "/"
    : props.href;

  if (linkSub === "/" || linkSub === "") {
    return currentSub === "/" || currentSub === "";
  }
  return currentSub === linkSub || currentSub.startsWith(linkSub + "/");
});
</script>

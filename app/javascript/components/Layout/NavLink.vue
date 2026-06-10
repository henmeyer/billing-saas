<template>
  <Link
    :href="href"
    :class="[
      'flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm',
      'transition-all duration-150 group',
      isActive
        ? 'bg-white/10 text-white font-medium'
        : 'text-gray-400 hover:bg-white/5 hover:text-gray-200 font-normal',
    ]"
  >
    <span class="flex-shrink-0 w-4 h-4 flex items-center justify-center">
      <component :is="iconComponent" />
    </span>
    <span class="truncate">{{ label }}</span>
  </Link>
</template>

<script setup>
import { computed, defineComponent, h } from "vue";
import { Link, usePage } from "@inertiajs/vue3";

const props = defineProps({
  href: String,
  icon: String,
  label: String,
  exact: Boolean,
});

const page = usePage();
const isActive = computed(() =>
  props.exact
    ? page.url === props.href
    : page.url === props.href || page.url.startsWith(props.href + "/"),
);

const icons = {
  dashboard: `<svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
    <path stroke-linecap="round" stroke-linejoin="round"
      d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2
         2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0
         011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"/>
  </svg>`,

  subscriptions: `<svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
    <path stroke-linecap="round" stroke-linejoin="round"
      d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11
         11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
  </svg>`,

  customers: `<svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
    <path stroke-linecap="round" stroke-linejoin="round"
      d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10
         0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0
         015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0
         0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z"/>
  </svg>`,

  plans: `<svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
    <path stroke-linecap="round" stroke-linejoin="round"
      d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2
         2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0
         012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"/>
  </svg>`,

  products: `<svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
    <path stroke-linecap="round" stroke-linejoin="round"
      d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8
         4v10M4 7v10l8 4"/>
  </svg>`,

  import: `<svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
    <path stroke-linecap="round" stroke-linejoin="round"
      d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4
         4m0 0l-4-4m4 4V4"/>
  </svg>`,

  integrations: `<svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
    <path stroke-linecap="round" stroke-linejoin="round"
      d="M8 9l3 3-3 3m5 0h3M5 20h14a2 2 0 002-2V6a2 2 0
         00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
  </svg>`,

  apikeys: `<svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
    <path stroke-linecap="round" stroke-linejoin="round"
      d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11
         17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6
         6 0 1121 9z"/>
  </svg>`,

  gateways: `<svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
    <path stroke-linecap="round" stroke-linejoin="round"
      d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0
         00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z"/>
  </svg>`,

  currencies: `<svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
    <path stroke-linecap="round" stroke-linejoin="round"
      d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343
         2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11
         0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
  </svg>`,

  license: `<svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
    <path stroke-linecap="round" stroke-linejoin="round"
      d="M15 9a2 2 0 10-4 0v5a2 2 0 01-2 2h6m-6-4h4m8 0a9 9 0
         11-18 0 9 9 0 0118 0z"/>
  </svg>`,

  credits: `<svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
    <path stroke-linecap="round" stroke-linejoin="round"
      d="M9 7h6m0 10v-3m-3 3h.01M9 17h.01M9 14h.01M12 14h.01M15
         11h.01M12 11h.01M9 11h.01M7 21h10a2 2 0 002-2V5a2 2 0
         00-2-2H7a2 2 0 00-2 2v14a2 2 0 002 2z"/>
  </svg>`,

  features: `<svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
    <path stroke-linecap="round" stroke-linejoin="round"
      d="M13 10V3L4 14h7v7l9-11h-7z"/>
  </svg>`,

  sa_dashboard: `<svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
    <path stroke-linecap="round" stroke-linejoin="round"
      d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0
         002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2
         0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0
         01-2-2z"/>
  </svg>`,

  sa_accounts: `<svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
    <path stroke-linecap="round" stroke-linejoin="round"
      d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2
         0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1
         1 0 011-1h2a1 1 0 011 1v5m-4 0h4"/>
  </svg>`,

  sa_users: `<svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
    <path stroke-linecap="round" stroke-linejoin="round"
      d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0
         0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"/>
  </svg>`,

  sa_admins: `<svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
    <path stroke-linecap="round" stroke-linejoin="round"
      d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955
         11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29
         9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"/>
  </svg>`,
};

const iconComponent = computed(() =>
  defineComponent({
    render: () =>
      h("span", {
        class: "w-4 h-4 block",
        innerHTML: icons[props.icon] || icons.dashboard,
      }),
  }),
);
</script>

<template>
  <div class="flex h-screen">
    <Sidebar :auth="auth" />

    <div class="flex-1 flex flex-col min-w-0 overflow-hidden">
      <Topbar :auth="auth" />

      <FlashMessages :flash="flash" />

      <main class="flex-1 overflow-y-auto px-6 py-6">
        <slot />
      </main>
    </div>
  </div>
</template>

<script setup>
import { usePage } from "@inertiajs/vue3";
import { computed } from "vue";
import Sidebar from "./Sidebar.vue";
import Topbar from "./Topbar.vue";
import FlashMessages from "./FlashMessages.vue";

const page = usePage();
const auth = computed(() => page.props.auth);
const flash = computed(() => page.props.flash);
</script>

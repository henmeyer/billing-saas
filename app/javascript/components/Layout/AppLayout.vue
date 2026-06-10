<template>
  <div class="flex h-screen">
    <Sidebar />

    <div class="flex-1 flex flex-col min-w-0 overflow-hidden">
      <Topbar />

      <FlashMessages :flash="flash" />

      <!-- Banner de impersonation -->
      <div
        v-if="auth.impersonating"
        class="bg-amber-500 text-amber-950 text-xs font-medium
                  px-4 py-2 flex items-center justify-between
                  flex-shrink-0"
      >
        <span>
          ⚠ Você está como
          <strong>{{ auth.user?.name }}</strong>
        </span>
        <Link
          href="/superadmin/impersonation/stop"
          class="underline hover:no-underline font-semibold"
        >
          Encerrar
        </Link>
      </div>

      <main class="flex-1 overflow-y-auto px-6 py-6">
        <slot />
      </main>
    </div>
  </div>
</template>

<script setup>
import { usePage } from "@inertiajs/vue3";
import { computed } from "vue";
import { Link } from "@inertiajs/vue3";
import Sidebar from "./Sidebar.vue";
import Topbar from "./Topbar.vue";
import FlashMessages from "./FlashMessages.vue";

const page = usePage();
const auth = computed(() => page.props.auth);
const flash = computed(() => page.props.flash);
</script>

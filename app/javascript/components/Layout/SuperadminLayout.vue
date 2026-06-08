<template>
  <div class="flex h-screen">
    <!-- Sidebar superadmin -->
    <nav class="w-56 bg-gray-950 flex flex-col flex-shrink-0">
      <div class="h-14 flex items-center px-4 border-b border-gray-800">
        <span class="text-white font-semibold text-sm tracking-wide">🛡️ SuperAdmin</span>
      </div>

      <div class="flex-1 py-4 overflow-y-auto">
        <div class="space-y-0.5 px-2">
          <SuperadminNavLink href="/superadmin" icon="◻" label="Dashboard" :exact="true" />

          <p class="text-xs font-medium text-gray-500 uppercase tracking-wider px-2 pt-4 pb-1">
            Contas
          </p>
          <SuperadminNavLink href="/superadmin/accounts" icon="◉" label="Contas" />
          <SuperadminNavLink href="/superadmin/users" icon="👤" label="Usuários" />

          <p class="text-xs font-medium text-gray-500 uppercase tracking-wider px-2 pt-4 pb-1">
            Admin
          </p>
          <SuperadminNavLink href="/superadmin/super_admins" icon="🛡" label="SuperAdmins" />
        </div>
      </div>

      <div class="border-t border-gray-800 px-4 py-3 space-y-2">
        <p class="text-xs text-gray-400 truncate">{{ auth?.user?.email }}</p>
        <Link
          href="/"
          class="block text-xs text-gray-500 hover:text-white transition-colors"
        >
          ← Voltar ao app
        </Link>
      </div>
    </nav>

    <!-- Main -->
    <div class="flex-1 flex flex-col min-w-0 overflow-hidden bg-gray-50">
      <!-- Topbar -->
      <div class="h-14 bg-white border-b border-gray-200 flex items-center px-6 gap-3">
        <div
          v-if="auth?.user?.impersonating"
          class="flex items-center gap-2 bg-amber-50 border border-amber-200 text-amber-800 text-xs px-3 py-1.5 rounded-full"
        >
          <span>⚠</span>
          <span>Impersonando usuário</span>
          <form method="post" action="/impersonation/stop" class="inline">
            <input type="hidden" name="_method" value="post" />
            <button type="submit" class="underline hover:no-underline">Encerrar</button>
          </form>
        </div>
        <div class="flex-1" />
        <span class="text-xs text-gray-500">{{ auth?.user?.name }}</span>
      </div>

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
import { Link } from "@inertiajs/vue3";
import FlashMessages from "./FlashMessages.vue";
import SuperadminNavLink from "./SuperadminNavLink.vue";

const page = usePage();
const auth = computed(() => page.props.auth);
const flash = computed(() => page.props.flash);
</script>

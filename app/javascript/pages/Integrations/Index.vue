<template>
  <AppLayout>
    <div class="page-header">
      <div>
        <h2 class="page-title">Integrações</h2>
        <p class="text-sm text-gray-500 mt-0.5">Webhooks de saída para sistemas externos</p>
      </div>
      <Link href="/integrations/new" class="btn-primary">Nova integração</Link>
    </div>

    <div v-if="!integrations.length" class="card">
      <div class="card-body text-center py-12">
        <p class="text-gray-400 text-sm mb-2">Nenhuma integração configurada.</p>
        <p class="text-gray-500 text-xs max-w-sm mx-auto mb-4">
          Integrações recebem webhooks quando eventos ocorrem no sistema.
        </p>
        <Link href="/integrations/new" class="btn-primary inline-flex">Criar integração</Link>
      </div>
    </div>

    <div v-else class="space-y-3">
      <div v-for="i in integrations" :key="i.id" class="card">
        <div class="card-body">
          <div class="flex items-start justify-between">
            <div class="flex-1">
              <div class="flex items-center gap-3 mb-1">
                <h3 class="font-medium text-gray-900">{{ i.name }}</h3>
                <Badge :variant="i.active ? 'green' : 'gray'">
                  {{ i.active ? "Ativa" : "Inativa" }}
                </Badge>
              </div>
              <p class="text-sm text-gray-500 font-mono">{{ i.url }}</p>
              <div class="flex flex-wrap gap-1.5 mt-2">
                <Badge v-for="event in i.events" :key="event" variant="blue">{{ event }}</Badge>
              </div>
            </div>
            <div class="flex gap-2 ml-4">
              <Link :href="`/integrations/${i.id}`" class="btn-secondary btn-sm">Gerenciar</Link>
              <ConfirmButton
                :message="`Desativar a integração ${i.name}?`"
                @confirm="deactivate(i.id)"
              >
                Desativar
              </ConfirmButton>
            </div>
          </div>
          <div v-if="i.last_error_at" class="mt-3 alert-warning text-xs">
            Último erro: {{ i.last_error_at }}
          </div>
        </div>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { Link, router } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";
import Badge from "@/components/Shared/Badge.vue";
import ConfirmButton from "@/components/Shared/ConfirmButton.vue";

defineProps({ integrations: Array });

const deactivate = (id) => router.delete(`/integrations/${id}`);
</script>

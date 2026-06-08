<template>
  <AppLayout>
    <div class="page-header">
      <div>
        <h2 class="page-title">Moedas</h2>
        <p class="text-sm text-gray-500 mt-0.5">Moedas aceitas pela conta</p>
      </div>
      <Link href="/currencies/new" class="btn-primary">Nova moeda</Link>
    </div>

    <div class="card">
      <div class="table-wrapper">
        <table class="table">
          <thead>
            <tr>
              <th>Código</th>
              <th>Nome</th>
              <th>Símbolo</th>
              <th>Padrão</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="!currencies.length">
              <td colspan="6" class="text-center text-gray-400 py-8">
                Nenhuma moeda cadastrada.
              </td>
            </tr>
            <tr v-for="c in currencies" :key="c.id">
              <td>
                <span class="font-mono font-medium text-gray-900">{{ c.code }}</span>
              </td>
              <td class="text-gray-700">{{ c.name }}</td>
              <td class="font-medium text-gray-900">{{ c.symbol }}</td>
              <td>
                <Badge v-if="c.default" variant="blue">Padrão</Badge>
                <span v-else class="text-gray-400 text-sm">—</span>
              </td>
              <td>
                <Badge :variant="c.active ? 'green' : 'gray'">
                  {{ c.active ? "Ativa" : "Inativa" }}
                </Badge>
              </td>
              <td class="text-right flex gap-2 justify-end">
                <Link :href="`/currencies/${c.id}/edit`" class="btn-secondary btn-sm">
                  Editar
                </Link>
                <ConfirmButton
                  v-if="!c.default"
                  :message="`Desativar ${c.code}?`"
                  @confirm="deactivate(c.id)"
                >
                  Desativar
                </ConfirmButton>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { Link, router } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";
import Badge from "@/components/Shared/Badge.vue";
import ConfirmButton from "@/components/Shared/ConfirmButton.vue";

defineProps({ currencies: Array });

const deactivate = (id) => router.delete(`/currencies/${id}`);
</script>

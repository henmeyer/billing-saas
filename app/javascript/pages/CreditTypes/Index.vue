<template>
  <AppLayout>
    <div class="page-header">
      <div>
        <h2 class="page-title">Tipos de crédito</h2>
        <p class="text-sm text-gray-500 mt-0.5">Créditos consumíveis disponíveis para planos</p>
      </div>
      <Link href="/credit_types/new" class="btn-primary">Novo tipo</Link>
    </div>

    <div v-if="!creditTypes.length" class="card">
      <div class="card-body text-center py-12">
        <p class="text-gray-400 text-sm mb-4">Nenhum tipo de crédito cadastrado.</p>
        <Link href="/credit_types/new" class="btn-primary inline-flex">Criar tipo</Link>
      </div>
    </div>

    <div v-else class="card">
      <div class="table-wrapper">
        <table class="table">
          <thead>
            <tr>
              <th>Chave</th>
              <th>Label</th>
              <th>Unidade</th>
              <th>Reset</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="ct in creditTypes" :key="ct.id">
              <td class="font-mono text-sm text-gray-700">{{ ct.key }}</td>
              <td class="font-medium text-gray-900">{{ ct.label }}</td>
              <td class="text-gray-500 text-sm">{{ ct.unit }}</td>
              <td>
                <Badge variant="blue">{{ resetLabel(ct.reset_cycle) }}</Badge>
              </td>
              <td class="text-right flex gap-2 justify-end">
                <Link :href="`/credit_types/${ct.id}/edit`" class="btn-secondary btn-sm">
                  Editar
                </Link>
                <ConfirmButton
                  :message="`Remover ${ct.label}?`"
                  @confirm="destroy(ct.id)"
                >
                  Remover
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

const props = defineProps({ credit_types: Array });
const creditTypes = props.credit_types || [];

const destroy = (id) => router.delete(`/credit_types/${id}`, { preserveState: false });

const resetLabel = (cycle) =>
  ({ billing_cycle: "Por ciclo", monthly: "Mensal", never: "Nunca" })[cycle] || cycle;
</script>

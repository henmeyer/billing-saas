<template>
  <AppLayout>
    <div class="page-header">
      <div>
        <h2 class="page-title">Features</h2>
        <p class="text-sm text-gray-500 mt-0.5">Flags booleanas para controle de funcionalidades por plano</p>
      </div>
      <Link href="/feature_types/new" class="btn-primary">Nova feature</Link>
    </div>

    <div v-if="!featureTypes.length" class="card">
      <div class="card-body text-center py-12">
        <p class="text-gray-400 text-sm mb-4">Nenhuma feature cadastrada.</p>
        <Link href="/feature_types/new" class="btn-primary inline-flex">Criar feature</Link>
      </div>
    </div>

    <div v-else class="card">
      <div class="table-wrapper">
        <table class="table">
          <thead>
            <tr>
              <th>Chave</th>
              <th>Label</th>
              <th>Descrição</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="ft in featureTypes" :key="ft.id">
              <td class="font-mono text-sm text-gray-700">{{ ft.key }}</td>
              <td class="font-medium text-gray-900">{{ ft.label }}</td>
              <td class="text-gray-500 text-sm">{{ ft.description || "—" }}</td>
              <td class="text-right flex gap-2 justify-end">
                <Link :href="`/feature_types/${ft.id}/edit`" class="btn-secondary btn-sm">
                  Editar
                </Link>
                <ConfirmButton
                  :message="`Remover ${ft.label}?`"
                  @confirm="destroy(ft.id)"
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
import ConfirmButton from "@/components/Shared/ConfirmButton.vue";

const props = defineProps({ feature_types: Array });
const featureTypes = props.feature_types || [];

const destroy = (id) => router.delete(`/feature_types/${id}`);
</script>

<template>
  <AppLayout>
    <div class="page-header">
      <div>
        <h2 class="page-title">Tipos de licença</h2>
        <p class="text-sm text-gray-500 mt-0.5">
          Licenças disponíveis para planos e integrações
        </p>
      </div>
      <Link href="/license_types/new" class="btn-primary">Novo tipo</Link>
    </div>

    <div v-if="!licenseTypes.length" class="card">
      <div class="card-body text-center py-12">
        <p class="text-gray-400 text-sm mb-4">
          Nenhum tipo de licença cadastrado.
        </p>
        <Link href="/license_types/new" class="btn-primary inline-flex"
          >Criar tipo</Link
        >
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
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="lt in licenseTypes" :key="lt.id">
              <td class="font-mono text-sm text-gray-700">{{ lt.key }}</td>
              <td class="font-medium text-gray-900">{{ lt.label }}</td>
              <td class="text-gray-500 text-sm">{{ lt.unit }}</td>
              <td class="text-right flex gap-2 justify-end">
                <Link
                  :href="`/license_types/${lt.id}/edit`"
                  class="btn-secondary btn-sm"
                >
                  Editar
                </Link>
                <ConfirmButton
                  :message="`Remover ${lt.label}?`"
                  @confirm="destroy(lt.id)"
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

const props = defineProps({ license_types: Array });
const licenseTypes = props.license_types || [];
console.log(licenseTypes);

const destroy = (id) =>
  router.delete(`/license_types/${id}`, { preserveState: false });
</script>

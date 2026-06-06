<template>
  <AppLayout>
    <div class="page-header">
      <div>
        <h2 class="page-title">Gateways de pagamento</h2>
        <p class="text-sm text-gray-500 mt-0.5">Conecte Stripe e Asaas para cobranças</p>
      </div>
      <Link href="/payment_gateways/new" class="btn-primary">Configurar gateway</Link>
    </div>

    <div v-if="!gateways.length" class="card">
      <div class="card-body text-center py-12">
        <p class="text-gray-400 text-sm mb-4">Nenhum gateway configurado.</p>
        <Link href="/payment_gateways/new" class="btn-primary inline-flex">Configurar agora</Link>
      </div>
    </div>

    <div v-else class="card">
      <div class="table-wrapper">
        <table class="table">
          <thead>
            <tr>
              <th>Gateway</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="g in gateways" :key="g.id">
              <td class="font-medium text-gray-900 capitalize">{{ g.provider }}</td>
              <td>
                <Badge :variant="g.active ? 'green' : 'gray'">
                  {{ g.active ? "Ativo" : "Inativo" }}
                </Badge>
              </td>
              <td class="text-right flex gap-2 justify-end">
                <Link :href="`/payment_gateways/${g.id}/edit`" class="btn-secondary btn-sm">
                  Editar
                </Link>
                <ConfirmButton
                  :message="`Desativar ${g.provider}?`"
                  @confirm="destroy(g.id)"
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

const props = defineProps({ gateways: Array });
const gateways = props.gateways || [];

const destroy = (id) => router.delete(`/payment_gateways/${id}`);
</script>

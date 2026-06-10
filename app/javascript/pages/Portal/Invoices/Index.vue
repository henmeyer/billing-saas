<template>
  <PortalLayout
    :customer="$page.props.customer"
    :branding="branding"
    :portal-config="portalConfig"
  >
    <h1 class="text-xl font-semibold text-gray-900 mb-6">
      Histórico de faturas
    </h1>

    <div v-if="!charges.length" class="card">
      <div class="card-body text-center py-12 text-gray-400">
        Nenhuma fatura encontrada.
      </div>
    </div>

    <div v-else class="card">
      <div class="table-wrapper border-0 rounded-none">
        <table class="table">
          <thead>
            <tr>
              <th>Data</th>
              <th>Valor</th>
              <th>Status</th>
              <th>Pago em</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="c in charges" :key="c.id">
              <td class="text-sm text-gray-700">{{ c.created_at }}</td>
              <td class="text-sm font-medium text-gray-900">
                {{ fmt(c.amount * 100) }}
              </td>
              <td>
                <Badge :variant="chargeVariant(c.status)">
                  {{ chargeLabel(c.status) }}
                </Badge>
              </td>
              <td class="text-sm text-gray-500">
                {{ c.paid_at || "—" }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </PortalLayout>
</template>

<script setup>
import PortalLayout from "@/components/Portal/PortalLayout.vue";
import Badge from "@/components/Shared/Badge.vue";

const props = defineProps({
  charges: Array,
  portal_config: Object,
  branding: Object,
});

const portalConfig = props.portal_config;

const chargeVariant = (s) =>
  ({
    paid: "green",
    pending: "yellow",
    failed: "red",
    refunded: "gray",
  })[s] || "gray";

const chargeLabel = (s) =>
  ({
    paid: "Pago",
    pending: "Pendente",
    failed: "Falhou",
    refunded: "Estornado",
  })[s] || s;

const fmt = (v) =>
  new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(
    (v || 0) / 100,
  );
</script>

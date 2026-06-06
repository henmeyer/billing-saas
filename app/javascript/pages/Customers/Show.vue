<template>
  <AppLayout>
    <div class="page-header">
      <div class="flex items-center gap-3">
        <Link href="/customers" class="text-sm text-gray-500 hover:text-gray-700">← Clientes</Link>
        <h2 class="page-title">{{ customer.name }}</h2>
        <Badge :variant="statusVariant(customer.status)">{{ statusLabel(customer.status) }}</Badge>
      </div>
      <Link :href="`/customers/${customer.id}/edit`" class="btn-secondary">Editar</Link>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
      <!-- Info + Assinatura -->
      <div class="space-y-4">
        <div class="card">
          <div class="card-header">
            <h3 class="text-sm font-medium text-gray-900">Informações</h3>
          </div>
          <div class="card-body space-y-3">
            <div>
              <p class="text-xs text-gray-500">E-mail</p>
              <p class="text-sm text-gray-900">{{ customer.email }}</p>
            </div>
            <div v-if="customer.document">
              <p class="text-xs text-gray-500">CPF/CNPJ</p>
              <p class="text-sm text-gray-900">{{ customer.document }}</p>
            </div>
            <div v-if="customer.external_id">
              <p class="text-xs text-gray-500">ID externo</p>
              <p class="text-sm font-mono text-gray-700">{{ customer.external_id }}</p>
            </div>
            <div>
              <p class="text-xs text-gray-500">Health score</p>
              <p :class="['text-xl font-semibold', healthClass(customer.health_score)]">
                {{ customer.health_score }}%
              </p>
            </div>
          </div>
        </div>

        <div v-if="!subscription" class="card">
          <div class="card-body text-center py-8">
            <p class="text-gray-400 text-sm mb-3">Sem assinatura ativa</p>
            <Link
              :href="`/customers/${customer.id}/subscriptions/new`"
              class="btn-primary inline-flex"
            >
              Criar assinatura
            </Link>
          </div>
        </div>

        <div v-if="subscription" class="card">
          <div class="card-header">
            <h3 class="text-sm font-medium text-gray-900">Assinatura</h3>
          </div>
          <div class="card-body space-y-3">
            <div class="flex items-center justify-between">
              <p class="text-sm font-medium text-gray-900">{{ subscription.plan_name }}</p>
              <Badge :variant="subVariant(subscription.status)">
                {{ subLabel(subscription.status) }}
              </Badge>
            </div>
            <div>
              <p class="text-xs text-gray-500">Valor</p>
              <p class="text-sm text-gray-700">{{ fmt(subscription.price) }}/mês</p>
            </div>
            <div>
              <p class="text-xs text-gray-500">Gateway</p>
              <p class="text-sm text-gray-700">{{ subscription.gateway }}</p>
            </div>
            <div v-if="subscription.current_period_end">
              <p class="text-xs text-gray-500">Próxima renovação</p>
              <p class="text-sm text-gray-700">{{ subscription.current_period_end }}</p>
            </div>
            <div class="flex gap-2 pt-3 border-t border-gray-100">
              <Link
                :href="`/customers/${customer.id}/subscriptions/${subscription.id}/edit`"
                class="btn-secondary btn-sm flex-1 justify-center"
              >
                Editar assinatura
              </Link>
            </div>
          </div>
        </div>
      </div>

      <!-- Créditos + Cobranças -->
      <div class="lg:col-span-2 space-y-4">
        <div v-if="snapshots.length" class="card">
          <div class="card-header">
            <h3 class="text-sm font-medium text-gray-900">Créditos — período atual</h3>
          </div>
          <div class="card-body space-y-4">
            <ProgressBar
              v-for="s in snapshots"
              :key="s.credit_type_key"
              :label="s.credit_type_label"
              :used="s.used"
              :limit="s.limit"
              :balance="s.balance"
              :percent="s.usage_percent"
              :unit="s.credit_type_unit"
            />
          </div>
        </div>

        <div class="card">
          <div class="card-header flex items-center justify-between">
            <h3 class="text-sm font-medium text-gray-900">Créditos avulsos</h3>
          </div>
          <div class="card-body">
            <div v-if="!availableProducts?.length" class="text-sm text-gray-400">
              Nenhum produto disponível.
              <Link href="/products/new" class="text-brand-600 hover:underline">Criar produto</Link>
            </div>
            <div v-else class="space-y-2">
              <div
                v-for="p in availableProducts"
                :key="p.id"
                class="flex items-center justify-between py-2 border-b border-gray-100 last:border-0"
              >
                <div>
                  <p class="text-sm font-medium text-gray-900">{{ p.name }}</p>
                  <p class="text-xs text-gray-400">
                    {{ fmtNum(p.credit_quantity) }} {{ p.credit_type?.unit }}s —
                    {{ fmt(p.price) }}
                  </p>
                </div>
                <ConfirmButton
                  :message="`Adicionar ${p.name} para ${customer.name}?`"
                  btn-class="btn-secondary btn-sm"
                  @confirm="addProduct(p.id)"
                >
                  Adicionar
                </ConfirmButton>
              </div>
            </div>
          </div>
        </div>

        <div class="card">
          <div class="card-header">
            <h3 class="text-sm font-medium text-gray-900">Últimas cobranças</h3>
          </div>
          <div v-if="!charges.length" class="card-body text-center text-sm text-gray-400 py-6">
            Nenhuma cobrança ainda
          </div>
          <div v-else class="table-wrapper border-0 rounded-none">
            <table class="table">
              <thead>
                <tr>
                  <th>Vencimento</th>
                  <th>Valor</th>
                  <th>Gateway</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="c in charges" :key="c.id">
                  <td class="text-gray-500">{{ c.due_date || "—" }}</td>
                  <td class="font-medium">{{ fmt(c.amount) }}</td>
                  <td><Badge variant="gray">{{ c.gateway }}</Badge></td>
                  <td>
                    <Badge :variant="chargeVariant(c.status)">{{ chargeLabel(c.status) }}</Badge>
                  </td>
                </tr>
              </tbody>
            </table>
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
import ProgressBar from "@/components/Shared/ProgressBar.vue";
import ConfirmButton from "@/components/Shared/ConfirmButton.vue";

const props = defineProps({
  customer: Object,
  subscription: Object,
  charges: Array,
  snapshots: Array,
  available_products: Array,
});

const availableProducts = props.available_products || [];

const addProduct = (productId) => {
  router.post(`/customers/${props.customer.id}/customer_products`, {
    product_id: productId,
  });
};

const fmt = (v) =>
  new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(v || 0);
const fmtNum = (v) => new Intl.NumberFormat("pt-BR").format(v || 0);
const healthClass = (s) =>
  s >= 70 ? "text-green-600" : s >= 40 ? "text-yellow-600" : "text-red-600";
const statusVariant = (s) =>
  ({ active: "green", churned: "gray", suspended: "red" })[s] || "yellow";
const statusLabel = (s) =>
  ({ active: "Ativo", churned: "Cancelado", suspended: "Suspenso" })[s] || s;
const subVariant = (s) =>
  ({ active: "green", past_due: "red", trialing: "blue", cancelled: "gray" })[s] || "yellow";
const subLabel = (s) =>
  ({ active: "Ativo", past_due: "Inadimplente", trialing: "Trial", cancelled: "Cancelado" })[s] || s;
const chargeVariant = (s) =>
  ({ paid: "green", failed: "red", pending: "yellow", refunded: "gray" })[s] || "gray";
const chargeLabel = (s) =>
  ({ paid: "Pago", failed: "Falhou", pending: "Pendente", refunded: "Reembolsado" })[s] || s;
</script>

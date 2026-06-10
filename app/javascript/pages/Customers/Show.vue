<template>
  <AppLayout>
    <div class="page-header">
      <div class="flex items-center gap-3">
        <Link
          href="/customers"
          class="text-sm text-gray-500 hover:text-gray-700"
          >← Clientes</Link
        >
        <h2 class="page-title">{{ customer.name }}</h2>
        <Badge :variant="statusVariant(customer.status)">{{
          statusLabel(customer.status)
        }}</Badge>
      </div>
      <Link :href="`/customers/${customer.id}/edit`" class="btn-secondary"
        >Editar</Link
      >
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
            <div v-if="customer.identities?.length">
              <p class="text-xs text-gray-500">Integrações vinculadas</p>
              <div class="space-y-1 mt-1">
                <div
                  v-for="identity in customer.identities"
                  :key="identity.integration_id"
                  class="flex items-center justify-between text-sm"
                >
                  <span class="text-gray-600">{{
                    identity.integration_name
                  }}</span>
                  <code
                    class="text-xs bg-gray-100 px-2 py-0.5 rounded font-mono"
                  >
                    {{ identity.external_id }}
                  </code>
                </div>
              </div>
            </div>
            <div>
              <p class="text-xs text-gray-500">Health score</p>
              <p
                :class="[
                  'text-xl font-semibold',
                  healthClass(customer.health_score),
                ]"
              >
                {{ customer.health_score }}%
              </p>
            </div>
          </div>
        </div>

        <!-- Empty state: no active subscriptions -->
        <div v-if="!activeSubscriptions.length" class="card">
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

        <!-- Subscription cards: one per active subscription -->
        <div v-for="sub in activeSubscriptions" :key="sub.id" class="card">
          <div class="card-header">
            <h3 class="text-sm font-medium text-gray-900">
              {{ sub.integration_name || "Assinatura" }}
            </h3>
          </div>
          <div class="card-body space-y-3">
            <div class="flex items-center justify-between">
              <p class="text-sm font-medium text-gray-900">
                {{ sub.plan_name }}
              </p>
              <Badge :variant="subVariant(sub.status)">
                {{ subLabel(sub.status) }}
              </Badge>
            </div>

            <!-- Preço do período atual -->
            <div class="bg-gray-50 rounded-lg px-3 py-2.5">
              <div class="flex justify-between text-sm mb-1">
                <span class="text-gray-500">Valor base</span>
                <span class="text-gray-700"
                  >{{ fmt(sub.period_base_cents / 100) }}/mês</span
                >
              </div>
              <div
                v-if="sub.has_extras"
                class="flex justify-between text-sm mb-1"
              >
                <span class="text-gray-500">Extras contratados</span>
                <span class="text-gray-700"
                  >+ {{ fmt(sub.period_extras_cents / 100) }}</span
                >
              </div>
              <div
                class="flex justify-between text-sm font-medium border-t border-gray-200 mt-1.5 pt-1.5"
              >
                <span class="text-gray-700">Total mensal</span>
                <span class="text-gray-900">{{
                  fmt(sub.period_amount_cents / 100)
                }}</span>
              </div>
            </div>

            <div>
              <p class="text-xs text-gray-500">Gateway</p>
              <p class="text-sm text-gray-700">{{ sub.gateway }}</p>
            </div>
            <div v-if="sub.current_period_end">
              <p class="text-xs text-gray-500">Próxima renovação</p>
              <p class="text-sm text-gray-700">{{ sub.current_period_end }}</p>
            </div>
            <div
              v-if="periodLicenses.length"
              class="mt-3 pt-3 border-t border-gray-100"
            >
              <p class="text-xs font-medium text-gray-500 mb-2">
                Licenças contratadas
              </p>
              <div class="space-y-1">
                <div
                  v-for="lic in periodLicenses"
                  :key="lic.license_type_key"
                  class="flex justify-between text-sm"
                >
                  <span class="text-gray-600">{{
                    lic.license_type_label
                  }}</span>
                  <div class="text-right">
                    <span class="font-medium text-gray-900">
                      {{ lic.unlimited ? "∞" : fmtNum(lic.quantity) }}
                      {{ lic.license_type_unit }}(s)
                    </span>
                    <span
                      v-if="!lic.unlimited && lic.used != null"
                      class="text-xs text-gray-400 ml-1"
                    >
                      ({{ lic.used }} em uso)
                    </span>
                  </div>
                </div>
              </div>
            </div>
            <div class="flex gap-2 pt-3 border-t border-gray-100">
              <Link
                :href="`/customers/${customer.id}/subscriptions/${sub.id}/edit`"
                class="btn-secondary btn-sm flex-1 justify-center"
              >
                Editar
              </Link>
            </div>
          </div>
        </div>
      </div>

      <!-- Créditos + Cobranças -->
      <div class="lg:col-span-2 space-y-4">
        <div v-if="snapshots.length" class="card">
          <div class="card-header">
            <h3 class="text-sm font-medium text-gray-900">
              Créditos — período atual
            </h3>
          </div>
          <div class="card-body space-y-4">
            <div v-for="s in snapshots" :key="s.credit_type_key">
              <ProgressBar
                :label="s.credit_type_label"
                :used="s.used"
                :limit="s.limit"
                :balance="s.balance"
                :percent="s.usage_percent"
                :unit="s.credit_type_unit"
              />
              <div
                v-if="periodCreditFor(s.credit_type_key)?.extras > 0"
                class="text-xs text-gray-400 mt-1 ml-0.5"
              >
                Base: {{ fmtNum(periodCreditFor(s.credit_type_key).base) }} +
                Extras:
                {{ fmtNum(periodCreditFor(s.credit_type_key).extras) }} ({{
                  periodCreditFor(s.credit_type_key).extra_packages
                }}
                pacote(s))
              </div>
            </div>
          </div>
        </div>

        <div class="card">
          <div class="card-header flex items-center justify-between">
            <h3 class="text-sm font-medium text-gray-900">Créditos avulsos</h3>
          </div>
          <div class="card-body">
            <div
              v-if="!availableProducts?.length"
              class="text-sm text-gray-400"
            >
              Nenhum produto disponível.
              <Link href="/products/new" class="text-brand-600 hover:underline"
                >Criar produto</Link
              >
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
          <div
            v-if="!charges.length"
            class="card-body text-center text-sm text-gray-400 py-6"
          >
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
                  <td>
                    <Badge variant="gray">{{ c.gateway }}</Badge>
                  </td>
                  <td>
                    <Badge :variant="chargeVariant(c.status)">{{
                      chargeLabel(c.status)
                    }}</Badge>
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
import { computed } from "vue";
import { Link, router } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";
import Badge from "@/components/Shared/Badge.vue";
import ProgressBar from "@/components/Shared/ProgressBar.vue";
import ConfirmButton from "@/components/Shared/ConfirmButton.vue";

const props = defineProps({
  customer: Object,
  subscriptions: { type: Array, default: () => [] },
  subscription: Object,
  charges: Array,
  snapshots: Array,
  available_products: Array,
  period_credits: Array,
  period_licenses: Array,
});

const activeSubscriptions = computed(() => props.subscriptions || []);

const availableProducts = props.available_products || [];
const periodCredits = props.period_credits || [];
const periodLicenses = props.period_licenses || [];

const periodCreditFor = (key) =>
  periodCredits.find((pc) => pc.credit_type_key === key);

const addProduct = (productId) => {
  router.post(`/customers/${props.customer.id}/customer_products`, {
    product_id: productId,
  });
};

const fmt = (v) =>
  new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(
    v || 0,
  );
const fmtNum = (v) => new Intl.NumberFormat("pt-BR").format(v || 0);
const healthClass = (s) =>
  s >= 70 ? "text-green-600" : s >= 40 ? "text-yellow-600" : "text-red-600";
const statusVariant = (s) =>
  ({ active: "green", churned: "gray", suspended: "red" })[s] || "yellow";
const statusLabel = (s) =>
  ({ active: "Ativo", churned: "Cancelado", suspended: "Suspenso" })[s] || s;
const subVariant = (s) =>
  ({ active: "green", past_due: "red", trialing: "blue", cancelled: "gray" })[
    s
  ] || "yellow";
const subLabel = (s) =>
  ({
    active: "Ativo",
    past_due: "Inadimplente",
    trialing: "Trial",
    cancelled: "Cancelado",
  })[s] || s;
const chargeVariant = (s) =>
  ({ paid: "green", failed: "red", pending: "yellow", refunded: "gray" })[s] ||
  "gray";
const chargeLabel = (s) =>
  ({
    paid: "Pago",
    failed: "Falhou",
    pending: "Pendente",
    refunded: "Reembolsado",
  })[s] || s;
</script>

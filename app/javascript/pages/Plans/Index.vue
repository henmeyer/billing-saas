<template>
  <AppLayout>
    <div class="page-header">
      <div>
        <h2 class="page-title">Planos</h2>
        <p class="text-sm text-gray-500 mt-0.5">Gerencie os planos de assinatura</p>
      </div>
      <Link href="/plans/new" class="btn-primary">Novo plano</Link>
    </div>

    <div v-if="!plans.length" class="card">
      <div class="card-body text-center py-12">
        <p class="text-gray-400 text-sm mb-4">Nenhum plano criado ainda.</p>
        <Link href="/plans/new" class="btn-primary inline-flex">Criar primeiro plano</Link>
      </div>
    </div>

    <div v-else class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
      <div
        v-for="plan in plans"
        :key="plan.id"
        class="card hover:border-brand-300 transition-colors"
      >
        <div class="card-body">
          <div class="flex items-start justify-between mb-3">
            <div>
              <h3 class="font-semibold text-gray-900">{{ plan.name }}</h3>
              <p class="text-2xl font-bold text-gray-900 mt-1">
                <template v-if="planPrice(plan)">
                  {{ planPrice(plan).currency_symbol }} {{ fmt(planPrice(plan).amount_cents / 100) }}
                  <span class="text-sm font-normal text-gray-400">
                    /{{ plan.billing_cycle === "monthly" ? "mês" : "ano" }}
                  </span>
                  <span class="text-xs font-normal text-gray-400 ml-1">
                    {{ planPrice(plan).currency_code }}
                  </span>
                </template>
                <span v-else class="text-sm font-normal text-gray-400">Sem preço</span>
              </p>
            </div>
            <Badge :variant="plan.active ? 'green' : 'gray'">
              {{ plan.active ? "Ativo" : "Inativo" }}
            </Badge>
          </div>

          <p v-if="plan.description" class="text-sm text-gray-500 mb-3">{{ plan.description }}</p>

          <!-- Licenças -->
          <div v-if="plan.licenses?.length" class="mb-3">
            <p class="text-xs font-medium text-gray-500 mb-1.5">Licenças</p>
            <div
              v-for="lic in plan.licenses"
              :key="lic.license_type_id"
              class="flex justify-between text-sm"
            >
              <span class="text-gray-600">{{ lic.label }}</span>
              <span class="font-medium">{{ lic.quantity === 0 ? "∞" : lic.quantity }}</span>
            </div>
          </div>

          <!-- Créditos -->
          <div v-if="plan.credits?.length" class="mb-4">
            <p class="text-xs font-medium text-gray-500 mb-1.5">Créditos</p>
            <div
              v-for="cred in plan.credits"
              :key="cred.credit_type_id"
              class="flex justify-between text-sm"
            >
              <span class="text-gray-600">{{ cred.label }}</span>
              <span class="font-medium">{{ fmtNum(cred.quantity) }}</span>
            </div>
          </div>

          <div class="flex gap-2 pt-3 border-t border-gray-100">
            <Link
              :href="`/plans/${plan.id}/edit`"
              class="btn-secondary btn-sm flex-1 justify-center"
            >
              Editar
            </Link>
            <ConfirmButton
              :message="`Deletar o plano ${plan.name}?`"
              btn-class="btn-danger btn-sm flex-1 justify-center"
              @confirm="deletePlan(plan.id)"
            >
              Deletar
            </ConfirmButton>
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

defineProps({ plans: Array });

const deletePlan = (id) => router.delete(`/plans/${id}`, { preserveState: false });

const planPrice = (plan) => {
  const prices = plan.prices || [];
  return prices.find((p) => p.default) || prices[0] || null;
};

const fmt = (val) =>
  new Intl.NumberFormat("pt-BR", { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(val || 0);
const fmtNum = (val) => new Intl.NumberFormat("pt-BR").format(val || 0);
</script>

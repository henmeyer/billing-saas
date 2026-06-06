<template>
  <AppLayout>
    <div class="page-header">
      <div class="flex items-center gap-3">
        <Link
          :href="`/customers/${customer.id}`"
          class="text-sm text-gray-500 hover:text-gray-700"
        >
          ← {{ customer.name }}
        </Link>
        <h2 class="page-title">
          {{ subscription.id ? "Editar assinatura" : "Nova assinatura" }}
        </h2>
      </div>
    </div>

    <div class="max-w-lg space-y-6">
      <div v-if="errors.length" class="alert-danger">
        <div>
          <p v-for="err in errors" :key="err">{{ err }}</p>
        </div>
      </div>

      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Dados da assinatura</h3>
        </div>
        <div class="card-body space-y-4">
          <div>
            <label class="form-label">Plano</label>
            <select v-model="form.plan_id" class="form-input">
              <option value="">Selecione um plano</option>
              <option v-for="p in plans" :key="p.id" :value="p.id">
                {{ p.name }} — {{ fmt(p.price) }}/{{ p.billing_cycle === "monthly" ? "mês" : "ano" }}
              </option>
            </select>
          </div>

          <div>
            <label class="form-label">Gateway de pagamento</label>
            <select v-model="form.gateway" class="form-input" :disabled="!!subscription.id">
              <option value="">Selecione o gateway</option>
              <option v-for="g in gateways" :key="g.id" :value="g.provider">
                {{ g.provider }}
              </option>
            </select>
            <p v-if="subscription.id" class="form-hint">
              Gateway não pode ser alterado após criação.
            </p>
          </div>

          <div v-if="!subscription.id">
            <label class="form-label">
              ID da assinatura no gateway
              <span class="text-gray-400 font-normal">(opcional)</span>
            </label>
            <input
              v-model="form.gateway_subscription_id"
              type="text"
              class="form-input font-mono"
              placeholder="Deixe em branco para gerar automaticamente"
            />
            <p class="form-hint">
              Se o cliente já tem assinatura ativa no gateway, cole o ID aqui.
            </p>
          </div>

          <div v-if="subscription.id">
            <label class="form-label">Status</label>
            <select v-model="form.status" class="form-input">
              <option value="active">Ativo</option>
              <option value="past_due">Inadimplente</option>
              <option value="trialing">Trial</option>
              <option value="cancelled">Cancelado</option>
            </select>
          </div>

          <div v-if="!subscription.id">
            <label class="form-label">Data de início</label>
            <input v-model="form.started_at" type="date" class="form-input" />
          </div>
        </div>
      </div>

      <div v-if="selectedPlan" class="card bg-gray-50">
        <div class="card-body">
          <p class="text-xs font-medium text-gray-500 uppercase mb-3">
            Resumo do plano selecionado
          </p>
          <div class="space-y-1 text-sm">
            <div class="flex justify-between">
              <span class="text-gray-600">Valor</span>
              <span class="font-medium">
                {{ fmt(selectedPlan.price) }}/{{ selectedPlan.billing_cycle === "monthly" ? "mês" : "ano" }}
              </span>
            </div>
          </div>
        </div>
      </div>

      <div class="flex gap-3 justify-end">
        <Link :href="`/customers/${customer.id}`" class="btn-secondary">
          Cancelar
        </Link>

        <ConfirmButton
          v-if="subscription.id"
          message="Cancelar esta assinatura? Esta ação não pode ser desfeita."
          btn-class="btn-danger"
          @confirm="cancelSubscription"
        >
          Cancelar assinatura
        </ConfirmButton>

        <button @click="submit" :disabled="form.processing" class="btn-primary">
          {{
            form.processing
              ? "Salvando..."
              : subscription.id
                ? "Salvar"
                : "Criar assinatura"
          }}
        </button>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { computed } from "vue";
import { Link, useForm, router } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";
import ConfirmButton from "@/components/Shared/ConfirmButton.vue";

const props = defineProps({
  customer: Object,
  subscription: Object,
  plans: Array,
  gateways: Array,
  errors: { type: [Array, Object], default: () => [] },
});

const form = useForm({
  plan_id: props.subscription.plan_id || "",
  gateway: props.subscription.gateway || "",
  gateway_subscription_id: props.subscription.gateway_subscription_id || "",
  status: props.subscription.status || "active",
  started_at:
    props.subscription.started_at || new Date().toISOString().split("T")[0],
});

const selectedPlan = computed(() =>
  props.plans.find((p) => p.id === Number(form.plan_id)),
);

const submit = () => {
  const base = `/customers/${props.customer.id}/subscriptions`;
  const url = props.subscription.id ? `${base}/${props.subscription.id}` : base;
  const method = props.subscription.id ? "put" : "post";
  form[method](url);
};

const cancelSubscription = () => {
  router.delete(
    `/customers/${props.customer.id}/subscriptions/${props.subscription.id}`,
  );
};

const fmt = (v) =>
  new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(
    v || 0,
  );
</script>

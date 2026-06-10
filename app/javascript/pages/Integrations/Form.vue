<template>
  <AppLayout>
    <div class="page-header">
      <div class="flex items-center gap-3">
        <Link
          href="/integrations"
          class="text-sm text-gray-500 hover:text-gray-700"
        >
          ← Integrações
        </Link>
        <h2 class="page-title">
          {{ integration.id ? "Editar" : "Nova" }} integração
        </h2>
      </div>
    </div>

    <div class="max-w-2xl space-y-6">
      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Configuração</h3>
        </div>
        <div class="card-body space-y-4">
          <div>
            <label class="form-label">Nome</label>
            <input
              v-model="form.name"
              type="text"
              class="form-input"
              placeholder="Ex: Meu Omnichannel, ERP Interno"
            />
            <p v-if="errors.name" class="form-error">
              {{ errors.name.join(", ") }}
            </p>
          </div>
          <div>
            <label class="form-label">URL do webhook</label>
            <input
              v-model="form.url"
              type="url"
              class="form-input"
              placeholder="https://meuapp.com/webhooks/billing"
            />
            <p v-if="errors.url" class="form-error">
              {{ errors.url.join(", ") }}
            </p>
          </div>
          <div>
            <label class="form-label">Máximo de tentativas</label>
            <input
              v-model.number="form.retry_count"
              type="number"
              min="1"
              max="10"
              class="form-input w-24"
            />
          </div>
        </div>
      </div>

      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Eventos</h3>
          <p class="text-xs text-gray-500 mt-0.5">
            Selecione os eventos que esta integração recebe
          </p>
        </div>
        <div class="card-body">
          <div class="grid grid-cols-2 gap-2">
            <label
              v-for="event in availableEvents"
              :key="event"
              class="flex items-center gap-2 text-sm text-gray-700 cursor-pointer"
            >
              <input
                type="checkbox"
                :value="event"
                v-model="form.events"
                class="rounded border-gray-300 text-brand-600 focus:ring-brand-500"
              />
              <span class="font-mono text-xs">{{ event }}</span>
            </label>
          </div>
        </div>
      </div>

      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Campos de licença</h3>
          <p class="text-xs text-gray-500 mt-0.5">
            Quais tipos de licença esta integração usa
          </p>
        </div>
        <div class="card-body">
          <div v-if="licenseTypes.length" class="space-y-2">
            <label
              v-for="lt in licenseTypes"
              :key="lt.id"
              class="flex items-center gap-2 text-sm text-gray-700 cursor-pointer"
            >
              <input
                type="checkbox"
                :value="lt.id"
                v-model="form.license_type_ids"
                class="rounded border-gray-300 text-brand-600 focus:ring-brand-500"
              />
              <span class="font-medium">{{ lt.label }}</span>
              <span class="text-gray-400 text-xs">{{ lt.key }}</span>
            </label>
          </div>
          <p v-else class="text-sm text-gray-400">
            Nenhum tipo de licença configurado.
          </p>
        </div>
      </div>

      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Campos de crédito</h3>
          <p class="text-xs text-gray-500 mt-0.5">
            Quais tipos de crédito esta integração usa
          </p>
        </div>
        <div class="card-body">
          <div v-if="creditTypes.length" class="space-y-2">
            <label
              v-for="ct in creditTypes"
              :key="ct.id"
              class="flex items-center gap-2 text-sm text-gray-700 cursor-pointer"
            >
              <input
                type="checkbox"
                :value="ct.id"
                v-model="form.credit_type_ids"
                class="rounded border-gray-300 text-brand-600 focus:ring-brand-500"
              />
              <span class="font-medium">{{ ct.label }}</span>
              <span class="text-gray-400 text-xs">{{ ct.key }}</span>
            </label>
          </div>
          <p v-else class="text-sm text-gray-400">
            Nenhum tipo de crédito configurado.
          </p>
        </div>
      </div>

      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Features</h3>
          <p class="text-xs text-gray-500 mt-0.5">
            Quais features esta integração suporta
          </p>
        </div>
        <div class="card-body">
          <div v-if="featureTypes.length" class="space-y-2">
            <label
              v-for="ft in featureTypes"
              :key="ft.id"
              class="flex items-center gap-2 text-sm text-gray-700 cursor-pointer"
            >
              <input
                type="checkbox"
                :value="ft.id"
                v-model="form.feature_type_ids"
                class="rounded border-gray-300 text-brand-600 focus:ring-brand-500"
              />
              <span class="font-medium">{{ ft.label }}</span>
              <span class="text-gray-400 font-mono text-xs">{{ ft.key }}</span>
            </label>
          </div>
          <p v-else class="text-sm text-gray-400">
            Nenhuma feature configurada ainda.
          </p>
        </div>
      </div>

      <!-- Portal do cliente -->
      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">Portal do cliente</h3>
          <p class="text-xs text-gray-500 mt-0.5">
            Configure o que o cliente pode ver e fazer no portal externo.
          </p>
        </div>
        <div class="card-body space-y-4">
          <!-- Branding -->
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="form-label">URL do logo</label>
              <input
                v-model="form.portal_logo_url"
                type="url"
                class="form-input text-sm"
                placeholder="https://..."
              />
            </div>
            <div>
              <label class="form-label">Cor principal</label>
              <div class="flex gap-2">
                <input
                  v-model="form.portal_primary_color"
                  type="color"
                  class="w-10 h-10 rounded cursor-pointer border-0"
                />
                <input
                  v-model="form.portal_primary_color"
                  type="text"
                  class="form-input text-sm font-mono flex-1"
                  placeholder="#6366f1"
                />
              </div>
            </div>
          </div>

          <!-- Toggles -->
          <div class="border-t border-gray-100 pt-4 space-y-3">
            <label
              v-for="opt in portalOptions"
              :key="opt.key"
              class="flex items-center justify-between cursor-pointer py-1 hover:bg-gray-50 -mx-2 px-2 rounded"
            >
              <div>
                <p class="text-sm text-gray-700">{{ opt.label }}</p>
                <p class="text-xs text-gray-400">{{ opt.desc }}</p>
              </div>
              <input
                type="checkbox"
                v-model="form.portal_config[opt.key]"
                class="rounded border-gray-300 text-brand-600 focus:ring-brand-500"
              />
            </label>
          </div>
        </div>
      </div>

      <div class="flex gap-3 justify-end">
        <Link href="/integrations" class="btn-secondary">Cancelar</Link>
        <button @click="submit" :disabled="form.processing" class="btn-primary">
          {{
            form.processing
              ? "Salvando..."
              : integration.id
                ? "Salvar"
                : "Criar integração"
          }}
        </button>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { Link, useForm } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";

const props = defineProps({
  integration: Object,
  available_events: Array,
  license_types: Array,
  credit_types: Array,
  feature_types: Array,
  errors: Object,
});

const availableEvents = props.available_events || [];
const licenseTypes = props.license_types || [];
const creditTypes = props.credit_types || [];
const featureTypes = props.feature_types || [];

const defaultPortalConfig = {
  allow_plan_change: true,
  allow_buy_products: true,
  allow_adjust_extras: true,
  show_invoice_history: true,
  allow_cancel: false,
};

const form = useForm({
  name: props.integration.name || "",
  url: props.integration.url || "",
  retry_count: props.integration.retry_count || 5,
  events: props.integration.events || [],
  license_type_ids: props.integration.license_type_ids || [],
  credit_type_ids: props.integration.credit_type_ids || [],
  feature_type_ids: props.integration.feature_type_ids || [],
  portal_logo_url: props.integration.portal_logo_url || "",
  portal_primary_color: props.integration.portal_primary_color || "#6366f1",
  portal_config: {
    ...defaultPortalConfig,
    ...(props.integration.portal_config || {}),
  },
});

const portalOptions = [
  {
    key: "allow_plan_change",
    label: "Trocar de plano",
    desc: "O cliente pode fazer upgrade ou downgrade do plano",
  },
  {
    key: "allow_buy_products",
    label: "Comprar produtos/pacotes",
    desc: "O cliente pode comprar pacotes de créditos extras",
  },
  {
    key: "allow_adjust_extras",
    label: "Ajustar créditos extras",
    desc: "O cliente pode ajustar pacotes extras da assinatura",
  },
  {
    key: "show_invoice_history",
    label: "Histórico de faturas",
    desc: "O cliente pode ver cobranças anteriores",
  },
  {
    key: "allow_cancel",
    label: "Cancelar assinatura",
    desc: "O cliente pode cancelar a assinatura diretamente",
  },
];

const submit = () => {
  const url = props.integration.id
    ? `/integrations/${props.integration.id}`
    : "/integrations";
  const method = props.integration.id ? "put" : "post";
  form[method](url);
};
</script>

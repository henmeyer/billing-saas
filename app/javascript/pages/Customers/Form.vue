<template>
  <AppLayout>
    <div class="page-header">
      <div class="flex items-center gap-3">
        <Link
          href="/customers"
          class="text-sm text-gray-500 hover:text-gray-700"
          >← Clientes</Link
        >
        <h2 class="page-title">
          {{ customer.id ? "Editar cliente" : "Novo cliente" }}
        </h2>
      </div>
    </div>

    <div class="max-w-2xl space-y-6">
      <!-- Erros -->
      <div v-if="Object.keys(errors).length" class="alert-danger">
        <div>
          <p v-for="(msgs, field) in errors" :key="field">
            <span class="font-medium capitalize">{{ fieldLabel(field) }}:</span>
            {{ msgs.join(", ") }}
          </p>
        </div>
      </div>

      <div class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">
            Informações do cliente
          </h3>
        </div>
        <div class="card-body space-y-4">
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="form-label">Nome</label>
              <input
                v-model="form.name"
                type="text"
                class="form-input"
                placeholder="Nome completo"
                required
              />
            </div>
            <div>
              <label class="form-label">E-mail</label>
              <input
                v-model="form.email"
                type="email"
                class="form-input"
                placeholder="cliente@empresa.com"
                required
              />
            </div>
          </div>

          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="form-label">
                {{ documentType.label }}
                <span class="text-red-500">*</span>
              </label>
              <input
                v-model="form.document"
                type="text"
                class="form-input"
                :placeholder="documentType.placeholder"
                required
              />
            </div>
            <div>
              <label class="form-label">Telefone</label>
              <input
                v-model="form.phone"
                type="text"
                class="form-input"
                placeholder="(11) 99999-9999"
              />
            </div>
          </div>

          <div v-if="customer.id">
            <label class="form-label">Status</label>
            <select v-model="form.status" class="form-input">
              <option value="active">Ativo</option>
              <option value="churned">Cancelado</option>
              <option value="suspended">Suspenso</option>
            </select>
          </div>

          <div>
            <label class="form-label">País</label>
            <select v-model="form.country" class="form-input">
              <optgroup label="América Latina">
                <option value="BR">Brasil</option>
                <option value="AR">Argentina</option>
                <option value="BO">Bolívia</option>
                <option value="CL">Chile</option>
                <option value="CO">Colômbia</option>
                <option value="CR">Costa Rica</option>
                <option value="DO">República Dominicana</option>
                <option value="EC">Equador</option>
                <option value="SV">El Salvador</option>
                <option value="GT">Guatemala</option>
                <option value="HN">Honduras</option>
                <option value="MX">México</option>
                <option value="NI">Nicarágua</option>
                <option value="PA">Panamá</option>
                <option value="PY">Paraguai</option>
                <option value="PE">Peru</option>
                <option value="UY">Uruguai</option>
                <option value="VE">Venezuela</option>
              </optgroup>
              <optgroup label="América do Norte">
                <option value="US">Estados Unidos</option>
                <option value="CA">Canadá</option>
              </optgroup>
              <optgroup label="Europa">
                <option value="PT">Portugal</option>
                <option value="ES">Espanha</option>
                <option value="FR">França</option>
                <option value="DE">Alemanha</option>
                <option value="IT">Itália</option>
                <option value="GB">Reino Unido</option>
                <option value="NL">Holanda</option>
                <option value="BE">Bélgica</option>
                <option value="CH">Suíça</option>
                <option value="PL">Polônia</option>
              </optgroup>
              <optgroup label="Ásia / Oceania">
                <option value="AU">Austrália</option>
                <option value="JP">Japão</option>
                <option value="CN">China</option>
                <option value="IN">Índia</option>
                <option value="SG">Singapura</option>
                <option value="AE">Emirados Árabes</option>
              </optgroup>
              <optgroup label="África">
                <option value="ZA">África do Sul</option>
                <option value="NG">Nigéria</option>
                <option value="KE">Quênia</option>
                <option value="EG">Egito</option>
              </optgroup>
            </select>
            <p class="form-hint">
              Usado para selecionar automaticamente o gateway de pagamento.
            </p>
          </div>

          <div>
            <label class="form-label">Moeda preferida</label>
            <select v-model.number="form.currency_id" class="form-input">
              <option value="">Usar padrão da conta</option>
              <option v-for="c in currencies" :key="c.id" :value="c.id">
                {{ c.code }} — {{ c.name }} ({{ c.symbol }})
              </option>
            </select>
            <p class="form-hint">
              Usada como padrão ao criar assinaturas para este cliente.
            </p>
          </div>

          <div>
            <label class="form-label">Observações</label>
            <textarea
              v-model="form.notes"
              rows="3"
              class="form-input"
              placeholder="Informações adicionais..."
            />
          </div>
        </div>
      </div>

      <!-- Identidades por integração -->
      <div v-if="integrations.length" class="card">
        <div class="card-header">
          <h3 class="text-sm font-medium text-gray-900">
            Identidades por integração
          </h3>
          <p class="text-xs text-gray-500 mt-0.5">
            ID deste cliente em cada sistema integrado. Usado pela API para
            identificar o cliente.
          </p>
        </div>
        <div class="card-body space-y-3">
          <div
            v-for="integration in integrations"
            :key="integration.id"
            class="flex items-center gap-3"
          >
            <div class="flex-1">
              <p class="text-sm font-medium text-gray-700">
                {{ integration.name }}
              </p>
              <p class="text-xs text-gray-400 font-mono">
                {{ integration.url }}
              </p>
            </div>
            <div class="w-48">
              <input
                v-model="identities[integration.id]"
                type="text"
                class="form-input text-sm font-mono"
                :placeholder="`ID no ${integration.name}`"
              />
            </div>
          </div>
        </div>
      </div>

      <div class="flex gap-3 justify-end">
        <Link href="/customers" class="btn-secondary">Cancelar</Link>
        <button @click="submit" :disabled="form.processing" class="btn-primary">
          {{
            form.processing
              ? "Salvando..."
              : customer.id
                ? "Salvar alterações"
                : "Criar cliente"
          }}
        </button>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { reactive, computed } from "vue";
import { Link, useForm } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";

const DOCUMENT_TYPES = {
  // América Latina
  BR: { label: "CPF / CNPJ",        placeholder: "000.000.000-00 ou 00.000.000/0001-00" },
  AR: { label: "DNI / CUIT",        placeholder: "12345678 ou 20-12345678-9" },
  BO: { label: "CI / NIT",          placeholder: "1234567 ou 1234567-1" },
  CL: { label: "RUT",               placeholder: "12.345.678-9" },
  CO: { label: "CC / NIT",          placeholder: "123456789 ou 900123456-1" },
  CR: { label: "Cédula / RUC",      placeholder: "123456789" },
  DO: { label: "Cédula / RNC",      placeholder: "000-0000000-0" },
  EC: { label: "CI / RUC",          placeholder: "1234567890 ou 12345678901" },
  SV: { label: "DUI / NIT",         placeholder: "00000000-0" },
  GT: { label: "DPI / NIT",         placeholder: "0000 00000 0101" },
  HN: { label: "DNI / RTN",         placeholder: "0000-0000-00000" },
  MX: { label: "CURP / RFC",        placeholder: "AAAA000000AAAAAA00" },
  NI: { label: "Cédula / RUC",      placeholder: "000-000000-0000A" },
  PA: { label: "Cédula / RUC",      placeholder: "0-000-0000" },
  PY: { label: "CI / RUC",          placeholder: "1234567 ou 80012345-0" },
  PE: { label: "DNI / RUC",         placeholder: "12345678 ou 12345678901" },
  UY: { label: "CI / RUT",          placeholder: "1234567-8" },
  VE: { label: "CI / RIF",          placeholder: "V-12345678" },
  // América do Norte
  US: { label: "SSN / EIN",         placeholder: "000-00-0000 ou 00-0000000" },
  CA: { label: "SIN / BN",          placeholder: "000 000 000" },
  // Europa
  PT: { label: "NIF / NIPC",        placeholder: "123456789" },
  ES: { label: "NIF / CIF",         placeholder: "12345678A ou A12345678" },
  FR: { label: "SIRET / NIF",       placeholder: "00000000000000" },
  DE: { label: "Steuer-ID / USt",   placeholder: "00 000 000 000" },
  IT: { label: "Codice Fiscale",    placeholder: "AAABBB00A00A000A" },
  GB: { label: "UTR / NI",          placeholder: "1234567890 ou AA123456A" },
  NL: { label: "BSN / BTW",         placeholder: "123456789" },
  BE: { label: "Rijksregister / BTW", placeholder: "00.00.00-000.00" },
  CH: { label: "AHV / MwSt",        placeholder: "756.0000.0000.00" },
  PL: { label: "PESEL / NIP",       placeholder: "00000000000 ou 000-000-00-00" },
  // Ásia / Oceania
  AU: { label: "TFN / ABN",         placeholder: "000 000 000 ou 00 000 000 000" },
  JP: { label: "My Number",         placeholder: "000000000000" },
  CN: { label: "身份证 / 统一信用代码",  placeholder: "000000000000000000" },
  IN: { label: "PAN / GSTIN",       placeholder: "AAAAA0000A ou 00AAAAA0000A0Z0" },
  SG: { label: "NRIC / UEN",        placeholder: "S1234567A ou 12345678A" },
  AE: { label: "Emirates ID / TRN", placeholder: "784-0000-0000000-0" },
  // África
  ZA: { label: "ID Number / VAT",   placeholder: "0000000000000" },
  NG: { label: "NIN / TIN",         placeholder: "00000000000" },
  KE: { label: "National ID / PIN", placeholder: "12345678" },
  EG: { label: "National ID / TIN", placeholder: "00000000000000" },
};

const DEFAULT_DOCUMENT = { label: "Documento", placeholder: "Número do documento" };

const props = defineProps({
  customer: Object,
  currencies: { type: Array, default: () => [] },
  integrations: { type: Array, default: () => [] },
  errors: Object,
});

const currencies = props.currencies;

const form = useForm({
  name: props.customer.name || "",
  email: props.customer.email || "",
  document: props.customer.document || "",
  phone: props.customer.phone || "",
  status: props.customer.status || "active",
  country: props.customer.country || "BR",
  currency_id: props.customer.currency_id || "",
  notes: props.customer.notes || "",
});

const documentType = computed(
  () => DOCUMENT_TYPES[form.country] ?? DEFAULT_DOCUMENT,
);

const identities = reactive(
  Object.fromEntries(
    props.integrations.map((integration) => {
      const existing = props.customer.identities?.find(
        (id) => id.integration_id === integration.id,
      );
      return [integration.id, existing?.external_id || ""];
    }),
  ),
);

const FIELD_LABELS = {
  name:        "Nome",
  email:       "E-mail",
  document:    "Documento",
  phone:       "Telefone",
  status:      "Status",
  country:     "País",
  currency_id: "Moeda",
  notes:       "Observações",
};

const fieldLabel = (field) => FIELD_LABELS[field] ?? field;

const submit = () => {
  const url = props.customer.id
    ? `/customers/${props.customer.id}`
    : "/customers";
  const method = props.customer.id ? "put" : "post";
  form.transform((data) => ({ ...data, identities }))[method](url);
};
</script>

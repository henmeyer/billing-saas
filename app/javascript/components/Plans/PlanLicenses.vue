<template>
  <div class="space-y-3">
    <div v-for="lt in licenseTypes" :key="lt.id" class="flex items-center gap-4">
      <div class="flex-1">
        <p class="text-sm font-medium text-gray-700">{{ lt.label }}</p>
        <p class="text-xs text-gray-400">{{ lt.key }}</p>
      </div>
      <div class="flex items-center gap-2">
        <input
          type="number"
          :name="`plan[plan_licenses_attributes][${lt.id}][quantity]`"
          v-model.number="lt.quantity"
          min="0"
          class="w-24 rounded-lg border-gray-300 text-sm focus:ring-brand-500 focus:border-brand-500"
        />
        <input
          type="hidden"
          :name="`plan[plan_licenses_attributes][${lt.id}][license_type_id]`"
          :value="lt.id"
        />
        <span class="text-xs text-gray-400 w-16">{{ lt.unit }}(s)</span>
        <span class="text-xs text-gray-400 italic" v-if="lt.quantity === 0">ilimitado</span>
      </div>
    </div>
    <p v-if="licenseTypes.length === 0" class="text-sm text-gray-400">
      Nenhum tipo de licença configurado.
      <a href="/license_types/new" class="text-brand-600 hover:underline">Criar tipo</a>
    </p>
  </div>
</template>

<script setup>
import { ref } from "vue";

const props = defineProps({
  licenseTypes: { type: Array, default: () => [] },
});

const licenseTypes = ref(props.licenseTypes);
</script>

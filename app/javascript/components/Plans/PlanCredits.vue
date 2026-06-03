<template>
  <div class="space-y-3">
    <div v-for="ct in creditTypes" :key="ct.id" class="flex items-center gap-4">
      <div class="flex-1">
        <p class="text-sm font-medium text-gray-700">{{ ct.label }}</p>
        <p class="text-xs text-gray-400">{{ ct.key }}</p>
      </div>
      <div class="flex items-center gap-2">
        <input
          type="number"
          :name="`plan[plan_credits_attributes][${ct.id}][quantity]`"
          v-model.number="ct.quantity"
          min="0"
          class="w-28 rounded-lg border-gray-300 text-sm focus:ring-brand-500 focus:border-brand-500"
        />
        <input
          type="hidden"
          :name="`plan[plan_credits_attributes][${ct.id}][credit_type_id]`"
          :value="ct.id"
        />
        <span class="text-xs text-gray-400 w-16">{{ ct.unit }}(s)</span>
        <label class="flex items-center gap-1.5 text-xs text-gray-500 cursor-pointer">
          <input
            type="checkbox"
            :name="`plan[plan_credits_attributes][${ct.id}][rollover]`"
            v-model="ct.rollover"
            class="rounded border-gray-300 text-brand-600"
          />
          Acumula
        </label>
      </div>
    </div>
    <p v-if="creditTypes.length === 0" class="text-sm text-gray-400">
      Nenhum tipo de crédito configurado.
      <a href="/credit_types/new" class="text-brand-600 hover:underline">Criar tipo</a>
    </p>
  </div>
</template>

<script setup>
import { ref } from "vue";

const props = defineProps({
  creditTypes: { type: Array, default: () => [] },
});

const creditTypes = ref(props.creditTypes);
</script>
